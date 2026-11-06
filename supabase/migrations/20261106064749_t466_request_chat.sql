-- T-466: counterpart-initiated contact before booking, with no profile/RLS broadening.
BEGIN;

CREATE FUNCTION app_private.request_chat_may_start(p_request uuid, p_groomer uuid, p_actor uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.grooming_requests r
    WHERE r.id=p_request AND r.status IN ('open','has_offers') AND r.expires_at>statement_timestamp()
      AND (
        (p_actor=p_groomer AND EXISTS (
          SELECT 1 FROM app_private.request_invitations i
          WHERE i.request_id=r.id AND i.groomer_id=p_groomer AND i.terms_revision=r.terms_revision
            AND i.withdrawn_at IS NULL AND i.declined_at IS NULL AND i.reply_by>statement_timestamp()
        ))
        OR (p_actor=r.customer_id AND EXISTS (
          SELECT 1 FROM public.groomer_offers o
          WHERE o.request_id=r.id AND o.groomer_id=p_groomer AND o.customer_id=r.customer_id
            AND o.status='pending' AND o.expires_at>statement_timestamp()
            AND app_private.evaluate_quote(o.id,statement_timestamp())->>'selectable'='true'
        ))
      )
  );
$function$;
REVOKE ALL ON FUNCTION app_private.request_chat_may_start(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION app_private.conversation_send_allowed(p_conversation uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
  SELECT auth.uid() IS NOT NULL AND NOT coalesce((auth.jwt()->>'is_anonymous')::boolean,false)
    AND EXISTS (
      SELECT 1 FROM public.conversations c JOIN public.profiles actor ON actor.id=auth.uid()
      WHERE c.id=p_conversation
        AND ((actor.id=c.customer_id AND actor.role='customer') OR (actor.id=c.groomer_id AND actor.role='groomer'))
        AND (
          EXISTS (SELECT 1 FROM public.messages m WHERE m.conversation_id=c.id AND m.kind='text')
          OR EXISTS (SELECT 1 FROM public.bookings b WHERE b.customer_id=c.customer_id AND b.groomer_id=c.groomer_id)
          OR EXISTS (SELECT 1 FROM public.grooming_requests r WHERE r.customer_id=c.customer_id
            AND r.status IN ('open','has_offers') AND r.expires_at>statement_timestamp()
            AND app_private.request_chat_may_start(r.id,c.groomer_id,actor.id))
        )
    );
$function$;
REVOKE ALL ON FUNCTION app_private.conversation_send_allowed(uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION app_private.request_chat_contact(p_request_id uuid,p_groomer_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE actor uuid:=auth.uid(); r public.grooming_requests%rowtype; conversation uuid; allowed boolean; name text;
BEGIN
  IF actor IS NULL OR coalesce((auth.jwt()->>'is_anonymous')::boolean,false) THEN
    RAISE EXCEPTION USING errcode='42501',message='not_allowed'; END IF;
  SELECT * INTO r FROM public.grooming_requests WHERE id=p_request_id;
  IF NOT FOUND OR NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=actor
    AND ((p.id=r.customer_id AND p.role='customer') OR (p.id=p_groomer_id AND p.role='groomer')))
    OR NOT EXISTS (SELECT 1 FROM public.request_matches m WHERE m.request_id=r.id AND m.groomer_id=p_groomer_id)
  THEN RAISE EXCEPTION USING errcode='42501',message='request_contact_unavailable'; END IF;
  SELECT id INTO conversation FROM public.conversations WHERE customer_id=r.customer_id AND groomer_id=p_groomer_id;
  allowed:=coalesce(app_private.conversation_send_allowed(conversation),false)
    OR app_private.request_chat_may_start(r.id,p_groomer_id,actor);
  IF allowed THEN
    SELECT nullif(btrim(display_name),'') INTO name FROM public.profiles
      WHERE id=CASE WHEN actor=p_groomer_id THEN r.customer_id ELSE p_groomer_id END;
  END IF;
  RETURN jsonb_build_object('can_message',allowed,'display_name',name,
    'conversation_id',CASE WHEN allowed THEN conversation END);
END $function$;
REVOKE ALL ON FUNCTION app_private.request_chat_contact(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION app_private.request_chat_contact(uuid,uuid) TO authenticated;
CREATE FUNCTION public.get_request_chat_contact(p_request_id uuid,p_groomer_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path TO '' AS $function$
  SELECT app_private.request_chat_contact(p_request_id,p_groomer_id);
$function$;
REVOKE ALL ON FUNCTION public.get_request_chat_contact(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.get_request_chat_contact(uuid,uuid) TO authenticated;

CREATE FUNCTION app_private.open_request_conversation(p_request_id uuid,p_groomer_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE contact jsonb; customer uuid; conversation uuid;
BEGIN
  IF auth.uid() IS NULL OR coalesce((auth.jwt()->>'is_anonymous')::boolean,false) THEN
    RAISE EXCEPTION USING errcode='42501',message='not_allowed'; END IF;
  -- The existing request row serializes opening against invitation/offer withdrawal.
  SELECT customer_id INTO customer FROM public.grooming_requests WHERE id=p_request_id FOR UPDATE;
  contact:=app_private.request_chat_contact(p_request_id,p_groomer_id);
  IF contact->>'can_message' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION USING errcode='42501',message='request_contact_unavailable'; END IF;
  INSERT INTO public.conversations(customer_id,groomer_id) VALUES(customer,p_groomer_id)
    ON CONFLICT(customer_id,groomer_id) DO UPDATE SET updated_at=public.conversations.updated_at
    RETURNING id INTO conversation;
  RETURN conversation;
END $function$;
REVOKE ALL ON FUNCTION app_private.open_request_conversation(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION app_private.open_request_conversation(uuid,uuid) TO authenticated;
CREATE FUNCTION public.open_request_conversation(p_request_id uuid,p_groomer_id uuid)
RETURNS uuid LANGUAGE sql SET search_path TO '' AS $function$
  SELECT app_private.open_request_conversation(p_request_id,p_groomer_id);
$function$;
REVOKE ALL ON FUNCTION public.open_request_conversation(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.open_request_conversation(uuid,uuid) TO authenticated;

CREATE FUNCTION app_private.guard_first_request_message()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
BEGIN
  IF new.kind='text' AND (new.sender_id IS DISTINCT FROM auth.uid()
    OR NOT app_private.conversation_send_allowed(new.conversation_id)) THEN
    RAISE EXCEPTION USING errcode='42501',message='request_contact_unavailable';
  END IF;
  RETURN new;
END $function$;
REVOKE ALL ON FUNCTION app_private.guard_first_request_message() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER messages_guard_first_contact BEFORE INSERT ON public.messages
FOR EACH ROW EXECUTE FUNCTION app_private.guard_first_request_message();

CREATE FUNCTION public.get_conversation_send_permissions(p_conversation_ids uuid[])
RETURNS TABLE(conversation_id uuid,can_send boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
BEGIN
  IF auth.uid() IS NULL OR coalesce((auth.jwt()->>'is_anonymous')::boolean,false)
    OR p_conversation_ids IS NULL OR cardinality(p_conversation_ids)>100
    OR array_position(p_conversation_ids,NULL) IS NOT NULL THEN
    RAISE EXCEPTION USING errcode='42501',message='not_allowed'; END IF;
  IF EXISTS(SELECT 1 FROM unnest(p_conversation_ids) AS requested(id) WHERE NOT EXISTS(
    SELECT 1 FROM public.conversations c JOIN public.profiles p ON p.id=auth.uid()
    WHERE c.id=requested.id AND ((c.customer_id=p.id AND p.role='customer') OR (c.groomer_id=p.id AND p.role='groomer'))
  )) THEN RAISE EXCEPTION USING errcode='42501',message='conversation_not_available'; END IF;
  RETURN QUERY SELECT c.id,app_private.conversation_send_allowed(c.id)
    FROM public.conversations c WHERE c.id=ANY(p_conversation_ids);
END $function$;
REVOKE ALL ON FUNCTION public.get_conversation_send_permissions(uuid[]) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.get_conversation_send_permissions(uuid[]) TO authenticated;
COMMIT;
