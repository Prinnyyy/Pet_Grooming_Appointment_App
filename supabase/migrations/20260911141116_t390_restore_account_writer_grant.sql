-- Preserve the existing invoker wrapper -> authenticated definer writer boundary.
grant execute on function app_private.request_account_deletion() to authenticated;
notify pgrst,'reload schema';
