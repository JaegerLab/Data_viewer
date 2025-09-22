classdef SessionData < handle
    properties
        fig struct
        video struct
        dlc struct
        emg struct
        gait struct

        currentFrame double = 0;
        currentTime double = 0;
        currentZoom double = [0 10];
    end

    events
        TimeChanged
        ZoomChanged
        DataChanged
        InfoChanged
    end

    methods (Access = private)
        % hide constructor as private to avoid creating multiple instances
        function obj = SessionData()
            % Private constructor
        end
    end

    methods (Static)
        % use static function to ensure sharing data with 1 instance.
        function obj = instance()
            persistent singleton
            if isempty(singleton) || ~isvalid(singleton)
                singleton = shared.SessionData();
            end
            obj = singleton;
        end
    end

    methods
        function setTime(obj, t)
            if obj.currentTime ~= t
                obj.currentTime = t;
                notify(obj, 'TimeChanged');
            end
        end

        function setZoom(obj, xlims)
            if ~isequal(obj.currentZoom, xlims)
                obj.currentZoom = xlims;
                notify(obj, 'ZoomChanged');
            end
        end

        % decide frame rate from different data sources
        function frameRate = getFrameRate(obj)
            if isfield(obj, 'frameRate')
                % 1st priority, manually corrected frame rate
                frameRate = obj.video.frameRate;
            elseif obj.has('dlc') && isfield(obj.dlc, 'frameRate')
                % manually corrected DLC frame rate
                frameRate = obj.dlc.frameRate;
            elseif obj.has('emg')
                % digital triggers recorded from Intan
                frameRate = obj.emg.trigger.freq;
            elseif obj.has('video')
                % video playback frame rate
                frameRate = obj.video.vid.FrameRate;
            else
                % without other data souce, use frame itself.
                frameRate = 1;
            end
        end

        % check if data section is available
        function tf = has(obj, objectName)
            tf = false;
            switch lower(objectName)
                case 'video'
                    if ~isempty(obj.video) && isfield(obj.video, 'vid') && ~isempty(obj.video.vid)
                        tf = true;
                    end
                case 'emg'
                    if ~isempty(obj.emg) && isfield(obj.emg, 'analog_data') && ~isempty(obj.emg.analog_data)
                        tf = true;
                    end
                case 'dlc'
                    if ~isempty(obj.dlc) && isfield(obj.dlc, 'table') && ~isempty(obj.dlc.table)
                        tf = true;
                    end
                case 'gait'
                    if ~isempty(obj.gait) && isfield(obj.gait, 'paw') && ~isempty(obj.gait.paw)
                        tf = true;
                    end
                case 'bpod'

                otherwise
                    tf = false;
            end
        end

    end
end
