module Orchestrator
  # This class hands jobs to invokers and puts them back on the queue if the
  # machine that is running them dies.
  #
  # The website adds each job to the `queued` list (see Exercism::ToolingJob).
  # When an invoker takes a job, we move the job to the `leased` list and give
  # it a deadline. Once the website knows the job's result, we remove the job
  # from `leased`. If the deadline passes first, RecoverStrandedJobs deals with
  # the job.
  #
  # The queue runs on clustered Valkey. There, one command can only touch
  # several keys if they are in the same hash slot. We start the name of each
  # key added here with "{<queued>}", which puts it in the same slot as
  # `queued`. Then LMOVE can move a job from `queued` to `leased` in one step,
  # so a crash can't lose it. The website's key keeps its name.
  class Queue
    include Singleton

    # This status means "gave up after repeated attempts". When a job has
    # gone back on the queue too many times, we save this status as its
    # result. The invoker lists it with its own statuses in Jobs::Job. The
    # website treats it like any other ops error, so the student sees an
    # error.
    RECLAIMS_EXHAUSTED_STATUS = 514

    def queued_key = Exercism::ToolingJob.key_for_queued
    def leased_key = slot_key("leased")
    def deadlines_key = slot_key("deadlines")
    def reclaims_key = slot_key("reclaims")
    def reports_key = slot_key("reports")
    def taken_key(id) = slot_key("taken:#{id}")

    # Jobs that are queued to run in the background wait on a separate list.
    # That list and `queued` are in different hash slots, so one command
    # can't move a job between them. Instead, we move the job to a `moving`
    # list in the background list's slot, and note the time. Then we add the
    # job to `queued`, and remove it from `moving`. If we crash part of the
    # way through, the job is still in `moving`, so it can't be lost.
    def background_key = Exercism::ToolingJob.key_for_queued_for_background_processing
    def moving_key = background_slot_key("moving")
    def moving_since_key = background_slot_key("moving_since")
    def recovering_key(id) = background_slot_key("recovering:#{id}")

    # This moves the next background job onto the main queue. It returns the
    # job's id, or nil if there are no background jobs.
    def promote_from_background
      id = redis.lmove(background_key, moving_key, :left, :right)
      return nil unless id

      redis.hset(moving_since_key, id, now)
      complete_promotion(id)
      id
    end

    # This finishes any move interrupted by a crash. If the crash came after
    # the job reached `queued`, the job will be on the queue twice. Then
    # either the student will get a duplicate retest, or we will drop the
    # second copy.
    #
    # If we crashed before we noted the time of the move, the job has no
    # time. We note the time now, so that the job will be recovered later.
    def recover_promotions
      ids = redis.lrange(moving_key, 0, -1).uniq
      return if ids.empty?

      redis.hmget(moving_since_key, *ids).zip(ids).each do |since, id|
        if since.nil?
          record_move_time(id)
        elsif since.to_f <= now - Orchestrator.config.promotion_timeout_seconds && take_recovery(id)
          complete_promotion(id)
        end
      end
    end

    # This takes the next job off the queue, moves it to `leased` and gives
    # it a deadline. It returns the job's id, or nil if the queue is empty.
    def claim
      id = redis.lmove(queued_key, leased_key, :left, :right)
      start_deadline(id) if id
      id
    end

    # This returns the job's deadline, or nil if we aren't holding the job.
    def deadline(id)
      value = redis.hget(deadlines_key, id)
      value&.to_f
    end

    # This returns true if the job is in the `leased` list.
    def leased?(id) = !redis.lpos(leased_key, id).nil?

    # Once the website knows a job's result, or once nobody can run the job,
    # this removes the job from `leased` and forgets everything else we know
    # about it. We remove it from `leased` first. If we crash after that, the
    # rest is only a few stale fields, and nothing will act on them.
    def finish(id)
      redis.lrem(leased_key, 1, id)
      redis.hdel(deadlines_key, id)
      redis.hdel(reclaims_key, id)
      redis.hdel(reports_key, id)
      redis.del(taken_key(id))
    end

    # This returns the ids of the jobs in `leased` that are out of time.
    #
    # If the orchestrator crashed after it moved a job to `leased` but before
    # it saved the deadline, the job has no deadline. We give such a job a
    # short deadline here, so that it will expire and come back.
    def expired_ids
      ids = redis.lrange(leased_key, 0, -1).uniq
      return [] if ids.empty?

      deadlines = redis.hmget(deadlines_key, *ids)
      ids.zip(deadlines).filter_map do |id, deadline|
        if deadline.nil?
          give_short_deadline(id)
          next
        end

        id if deadline.to_f <= now
      end
    end

    # Before anything deals with a job that is out of time, it must take the
    # job. This returns true if it took the job, and false if someone else
    # has already taken it. The claim lasts RETRY_SECONDS. If whoever took
    # the job fails to deal with it, the claim will run out, and a later pass
    # will try again.
    def take(id)
      redis.set(taken_key(id), 1, nx: true, ex: Orchestrator.config.retry_seconds) ? true : false
    end

    # This puts a job that we have taken back at the front of the queue. It
    # returns :requeued, or :failed if the job has already gone back too many
    # times. In that case it leaves the job in `leased`, and the caller should
    # fail it.
    #
    # We add the job to `queued` before we remove it from `leased`. If we
    # crash in between, the job will be in both lists, and it may run twice.
    # It can't be lost.
    def requeue(id)
      return :failed if redis.hget(reclaims_key, id).to_i >= Orchestrator.config.max_reclaims

      redis.hincrby(reclaims_key, id, 1)
      redis.lpush(queued_key, id)
      redis.lrem(leased_key, 1, id)
      redis.hdel(deadlines_key, id)
      redis.del(taken_key(id))
      :requeued
    end

    # ProcessJob calls this before it saves a job's result. It makes sure the
    # job is in `leased`, with a deadline RETRY_SECONDS away.
    #
    # This matters if the job's deadline passed while the invoker was still
    # running it, so that we had already put the job back on the queue.
    # Saving the result removes the job from `queued`. Without this step, if
    # the call to the website then failed, the job would be in neither list,
    # and the website would never get the result. The soak test found this.
    def hold(id)
      redis.rpush(leased_key, id) unless leased?(id)
      redis.hset(deadlines_key, id, now + Orchestrator.config.retry_seconds)
    end

    # This counts one more attempt to tell the website about a job's result,
    # and returns the new count.
    def count_report_attempt(id)
      redis.hincrby(reports_key, id, 1)
    end

    private
    def complete_promotion(id)
      redis.rpush(queued_key, id)
      redis.lrem(moving_key, 1, id)
      redis.hdel(moving_since_key, id)
    end

    # Only one orchestrator task can recover each job, so two tasks never add
    # the same job to `queued` twice.
    def take_recovery(id)
      redis.set(recovering_key(id), 1, nx: true, ex: Orchestrator.config.promotion_timeout_seconds)
    end

    # If the move finished between our reads of `moving` and `moving_since`,
    # the job is no longer in `moving`, and nothing would ever remove the new
    # time. So we check, and remove it.
    def record_move_time(id)
      redis.hsetnx(moving_since_key, id, now)
      redis.hdel(moving_since_key, id) if redis.lpos(moving_key, id).nil?
    end

    def background_slot_key(name) = "{#{background_key}}:#{name}"

    # If the job finished between our reads of `leased` and `deadlines`, it
    # is no longer in `leased`, and nothing would ever remove the new
    # deadline. So we check, and remove it.
    def give_short_deadline(id)
      redis.hsetnx(deadlines_key, id, now + Orchestrator.config.deadline_grace_seconds)
      redis.hdel(deadlines_key, id) unless leased?(id)
    end

    def start_deadline(id)
      redis.hset(deadlines_key, id, now + Orchestrator.config.lease_seconds)
    end

    def slot_key(name) = "{#{queued_key}}:#{name}"
    def now = Time.now.to_f
    def redis = Exercism.redis_tooling_client
  end
end
