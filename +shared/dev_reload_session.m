function dev_reload_session()
    % 1) Ask viewers to detach (optional but nice)
    try
        S = shared.SessionData.instance();

    catch
        S = []; 
    end

    % 2) Delete known listeners / release refs your GUI stored
    % (example if you stored them centrally in SessionData)
    try
        if ~isempty(S) && isprop(S,'Listeners')
            for k = numel(S.Listeners):-1:1
                delete(S.Listeners{k});
            end
            S.Listeners = {};
        end
    catch ME
        warning(ME.identifier, '%s', ME.message);
    end


    % 3) Clear the singleton persistent
    clear shared.SessionData.instance

    % 4) Clear class definitions so new events/properties are visible
    clear classes
    rehash % optional: refresh file cache

    % 5) Reacquire a fresh session (viewers can rebind after this)
    Snew = shared.SessionData.instance(); %#ok<NASGU>
end
