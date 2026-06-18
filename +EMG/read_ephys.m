function data = read_ephys(files)
% Read Open Ephys and convert it to Intan compatible format.
% go to https://github.com/open-ephys/open-ephys-matlab-tools
% for ephys reader installation and documentation.

session = Session(files);
data = struct();
if isempty(session.recordNodes); return; end

keys = session.recordNodes{1}.recordings{1}.continuous.keys();
key_name = keys{1};
recording = session.recordNodes{1}.recordings{1}.continuous(key_name);

channel_names = recording.metadata.names;
data.sample_rate = recording.metadata.sampleRate;

% get data from analog channels
analog_chans = startsWith(channel_names, 'CH');
if any(analog_chans)
    data.analog_data = double(recording.samples(analog_chans,:)');
    data.analog_channels = channel_names(analog_chans);
end

% get data from ADC channels
adc_chans = startsWith(channel_names, 'ADC');
if any(adc_chans)
    data.adc_data = double(recording.samples(adc_chans,:)');
end

% get trigger event time
triggers = session.recordNodes{1}.recordings{1}.ttlEvents(key_name);
data.trigger.time = triggers.timestamp(triggers.state);

% get time sample
data.t = recording.timestamps - recording.metadata.startTimestamp;

% save files
data.files = files;


