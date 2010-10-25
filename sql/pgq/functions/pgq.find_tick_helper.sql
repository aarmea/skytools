create or replace function pgq.find_tick_helper(
    in i_queue_id int4,
    in i_prev_tick_id int8,
    in i_prev_tick_time timestamptz,
    in i_prev_tick_seq int8,
    in i_min_count int8,
    in i_min_interval interval,
    out next_tick_id int8,
    out next_tick_time timestamptz,
    out next_tick_seq int8)
as $$
-- ----------------------------------------------------------------------
-- Function: pgq.find_tick_helper(6)
--
--      Helper function for pgq.next_batch_custom() to do extended tick search.
-- ----------------------------------------------------------------------
declare
    ok      boolean;
    t       record;
    cnt     int8;
    ival    interval;
begin
    -- first, fetch last tick of the queue
    select tick_id, tick_time, tick_event_seq into t
        from pgq.tick
        where tick_queue = i_queue_id
          and tick_id > i_prev_tick_id
        order by tick_queue desc, tick_id desc
        limit 1;
    if not found then
        return;
    end if;
    
    -- check if it is reasonably ok
    ok := true;
    if i_min_count is not null then
        cnt = t.tick_event_seq - i_prev_tick_seq;
        if cnt < i_min_count then
            return;
        end if;
        if cnt > i_min_count * 2 then
            ok := false;
        end if;
    end if;
    if i_min_interval is not null then
        ival = t.tick_time - i_prev_tick_time;
        if ival < i_min_interval then
            return;
        end if;
        if ival > i_min_interval * 2 then
            ok := false;
        end if;
    end if;

    -- if last tick too far away, do large scan
    if not ok then
        select tick_id, tick_time, tick_event_seq into t
            from pgq.tick
            where tick_queue = i_queue_id
              and tick_id > i_prev_tick_id
              and (i_min_count is null or (tick_event_seq - i_prev_tick_seq) >= i_min_count)
              and (i_min_interval is null or (tick_time - i_prev_tick_time) >= i_min_interval)
            order by tick_queue asc, tick_id asc
            limit 1;
    end if;
    next_tick_id := t.tick_id;
    next_tick_time := t.tick_time;
    next_tick_seq := t.tick_event_seq;
    return;
end;
$$ language plpgsql stable;

