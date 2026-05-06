-- Secure RPCs to handle session-based actor capture for Trust System
CREATE OR REPLACE FUNCTION public.verify_site_gps_v2(
    p_visit_id uuid,
    p_actor_id uuid,
    p_is_inside boolean,
    p_lat numeric,
    p_lng numeric,
    p_accuracy numeric, 
    p_distance numeric
) RETURNS jsonb AS $$
    DECLARE
        v_row_count int;
    BEGIN
        -- Set session variable within the transaction
        PERFORM set_config('app.current_user_id', p_actor_id::text, true);

        UPDATE public.site_visits
        SET
            gps_status = CASE WHEN p_is_inside THEN 'verified' ELSE 'rejected' END,
            submitted_lat = p_lat,
            submitted_lng = p_lng,
            gps_accuracy_meters = p_accuracy,
            distance_from_project_meters = p_distance,
            gps_verified_at = now(),
            status = CASE WHEN p_is_inside THEN 'gps_verified' ELSE 'invalid' END
        WHERE id = p_visit_id
        AND sourcing_manager_id = p_actor_id
        AND status IN ('scheduled', 'started');

        GET DIAGNOSTICS v_row_count = ROW_COUNT;
        RETURN jsonb_build_object('ok', v_row_count > 0);
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.upload_site_photo_v2(
    p_visit_id uuid,
    p_actor_id uuid,
    p_photo_sha256 text
) RETURNS jsonb AS $$
    DECLARE
        v_row_count int;
    BEGIN
        PERFORM set_config('app.current_user_id', p_actor_id::text, true);

        UPDATE public.site_visits
        SET
            photo_sha256 = p_photo_sha256,
            photo_uploaded_at = now(),
            photo_verification_status = 'verified', -- Auto-verify for now
            status = 'photo_verified'
        WHERE id = p_visit_id
        AND sourcing_manager_id = p_actor_id
        AND status = 'gps_verified';

        GET DIAGNOSTICS v_row_count = ROW_COUNT;
        RETURN jsonb_build_object('ok', v_row_count > 0);
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.broker_review_site_visit_v2(
    p_visit_id uuid,
    p_actor_id uuid,
    p_action text,
    p_reason text
) RETURNS jsonb AS $$
    DECLARE
        v_row_count int;
    BEGIN
        PERFORM set_config('app.current_user_id', p_actor_id::text, true);

        UPDATE public.site_visits
        SET
            broker_review_status = CASE WHEN p_action = 'approve' THEN 'approved' ELSE 'rejected' END,
            broker_reviewed_at = now(),
            broker_rejection_reason = p_reason,
            status = CASE WHEN p_action = 'approve' THEN 'completed' ELSE 'invalid' END
        WHERE id = p_visit_id
        AND broker_id = p_actor_id
        AND status = 'photo_verified';

        GET DIAGNOSTICS v_row_count = ROW_COUNT;
        RETURN jsonb_build_object('ok', v_row_count > 0);
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
