alter table public.customer_push_tokens
drop constraint if exists customer_push_tokens_token_check;

alter table public.customer_push_tokens
add constraint customer_push_tokens_token_check check (
  token = lower(token)
  and length(token) between 32 and 256
  and token ~ '^[0-9a-f]+$'
) not valid;

alter table public.customer_push_tokens
validate constraint customer_push_tokens_token_check;
