# A queue is not a record anywhere in Solid Queue -- it is a string repeated in
# the queue_name column of six tables. The other eight screens are grids because
# they each have a real table behind them; this one has nothing to grid.
#
# It used to manufacture rows with a `queues` database view so wulin_master's
# grid pipeline had a relation to query. That bought five read-only columns and
# three buttons at the price of a view named `public.queues`, a migration whose
# version every host app shared, a SQL file and a placeholder token -- and in a
# database shared by several apps the last deploy silently repointed the view at
# its own tables, so each app saw the other's queues.
#
# SolidQueue::Queue already does all of it in plain Ruby (.all, #paused?, #pause,
# #resume, #clear), so this is a panel over that.
class SolidQueueQueuePanel < WulinMaster::Panel
  title "Queues"
  # .panel_container is float:left, so with no width it shrink-wraps to its
  # content and leaves the rest of the screen empty -- which also made the card
  # grid wrap earlier than it needed to. Take the full width and let the flex
  # grid decide how many cards fit.
  width "100%"

  Row = Struct.new(:name, :pending, :scheduled, :blocked, :paused, keyword_init: true)

  # Five small grouped/distinct reads, every one of them index-only, in place of
  # the view's UNION. Names come from the jobs table like SolidQueue::Queue.all,
  # plus the pauses and recurring_tasks tables: a paused or scheduled-only queue
  # has nothing in the execution tables, and a queue you cannot see is a queue
  # you cannot resume.
  def rows
    @rows ||= begin
      pending = SolidQueue::ReadyExecution.group(:queue_name).count
      scheduled = SolidQueue::ScheduledExecution.group(:queue_name).count
      blocked = SolidQueue::BlockedExecution.group(:queue_name).count
      paused = SolidQueue::Pause.pluck(:queue_name).to_set

      names = SolidQueue::Job.distinct.pluck(:queue_name)
      names |= pending.keys | scheduled.keys | blocked.keys | paused.to_a
      names |= SolidQueue::RecurringTask.distinct.pluck(:queue_name)

      names.compact.sort.map do |name|
        Row.new(
          name: name,
          pending: pending.fetch(name, 0),
          scheduled: scheduled.fetch(name, 0),
          blocked: blocked.fetch(name, 0),
          paused: paused.include?(name)
        )
      end
    end
  end
end
