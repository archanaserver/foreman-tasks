module Actions
  class BulkAction < Actions::ActionWithSubPlans
    # == Parameters:
    # actions_class::
    #   Class of action to trigger on targets
    # targets::
    #   Array of objects on which the action_class should be triggered
    # *args::
    #   Arguments that all the targets share
    def plan(action_class, targets, *args, concurrency_limit: nil, **kwargs)
      check_targets!(targets)
      limit_concurrency_level!(concurrency_limit) if concurrency_limit
      plan_self(:action_class => action_class.to_s,
                :target_ids => targets.map(&:id),
                :target_class => targets.first.class.to_s,
                :args => args,
                :kwargs => kwargs)
    end

    def run(event = nil)
      super unless event == Dynflow::Action::Skip
    end

    def humanized_name
      if task.sub_tasks.first
        task.sub_tasks.first.humanized[:action]
      else
        _('Bulk action')
      end
    end

    def rescue_strategy
      Dynflow::Action::Rescue::Skip
    end

    def humanized_input
      a_sub_task = task.sub_tasks.first
      if a_sub_task
        [a_sub_task.humanized[:action].to_s.downcase] +
          Array(a_sub_task.humanized[:input]) + ['...']
      end
    end

    # @api override when the logic for the initiation of the subtasks
    #      is different from the default one
    def create_sub_plans
      action_class = input[:action_class].constantize
      target_class = input[:target_class].constantize
      targets = target_class.unscoped.where(:id => current_batch)

      missing = Array.new((current_batch - targets.map(&:id)).count) { nil }

      (targets + missing).map do |target|
        trigger(action_class, target, *input[:args], **input[:kwargs])
      end
    end

    def check_targets!(targets)
      raise Foreman::Exception, N_('Empty bulk action') if targets.empty?
      if targets.map(&:class).uniq.length > 1
        raise Foreman::Exception, N_('The targets are of different types')
      end
    end

    def batch(from, size)
      input[:target_ids].slice(from, size)
    end

    def total_count
      input[:target_ids].count
    end
  end
end
