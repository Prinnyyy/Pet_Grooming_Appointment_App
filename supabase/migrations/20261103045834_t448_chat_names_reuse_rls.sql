-- Reuse the existing participant conversation/profile SELECT policies, including
-- their current-role checks. Keep the bounded conversation scope and narrow result.
alter function public.get_chat_counterpart_names(uuid[]) security invoker;
