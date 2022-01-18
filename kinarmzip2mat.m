function kinarmzip2mat(filename)
% function that convert .zip files from the KINARM platform to .mat files
% structured in a way that is compatible with the mat2bin.py script.
% ---
% O.Codol - codol.olivier@gmail.com
% 08-Oct-2021
% ---


%=============================
% HANDLE INPUT
%=============================

% convert to char if input is string
if isstring(filename)
    filename = char(filename);
end

% check for input type
if ~ischar(filename)
    error('input must be a string or char array indicating the full path of a file or directory.')
end

% if input is not a .zip file, it is assumed to be a directory, so this
% script is called recursively for each .zip file contained in the directory
if ~strcmpi(filename(end-3:end), '.zip')
    cd(filename)
    filelist = ls;
    filelist = mat2cell(filelist, ones(size(filelist,1),1), size(filelist,2));
    zips = cellfun(@(x) contains(x, '.zip'), filelist);
    filelist = cellfun(@(x) regexprep(x, ' ', ''), filelist(zips), 'UniformOutput', false);
    nfiles = numel(filelist);
    for file = 1:nfiles-1
        kinarmzip2mat(filelist{file})
    end
    filename = filelist{end};
end


%=============================
% ECTRACT DATA
%=============================

data_in = zip_load(filename);
sorted_data = sort_trials(data_in,'execution');
data = KINARM_add_hand_kinematics(sorted_data.c3d);


%=============================
% EXPERIMENT INFO
%=============================

SESSION_DATA.SAMPLERATE = data(1).HAND.RATE;
SESSION_DATA.HAND_UNIT = data(1).HAND.UNITS;
SESSION_DATA.ACTIVE_ARM = data(1).EXPERIMENT.ACTIVE_ARM;
SESSION_DATA.START_DATE_TIME = data(1).EXPERIMENT.START_DATE_TIME;
SESSION_DATA.TASK_PROGRAM = data(1).EXPERIMENT.TASK_PROGRAM;
SESSION_DATA.TASK_PROTOCOL = data(1).EXPERIMENT.TASK_PROTOCOL;
SESSION_DATA.USE_REPEAT_TRIAL_FLAG = data(1).EXPERIMENT.USE_REPEAT_TRIAL_FLAG;
SESSION_DATA.REFRESH_RATE = data(1).VIDEO_SETTINGS.REFRESH_RATE;
OUTPUT{1} = 'SESSION_DATA';

if isfield(data(1), 'LOAD_TABLE')
    LOAD_TABLE = rmfield(data(1).LOAD_TABLE, {'COLUMN_ORDER', 'USED', 'DESCRIPTIONS'});
    OUTPUT{numel(OUTPUT)+1} = 'LOAD_TABLE';
end

if isfield(data(1), 'LOAD_TABLE')
    TARGET_TABLE = rmfield(data(1).TARGET_TABLE,...
        {'COLUMN_ORDER', 'USED', 'DESCRIPTIONS', 'FRAME_OF_REFERENCE', 'FRAME_OF_REFERENCE_LIST'});
	OUTPUT{numel(OUTPUT)+1} = 'TARGET_TABLE';
end

BLOCK_TABLE = rmfield(data(1).BLOCK_TABLE, {'USED', 'DESCRIPTIONS'});
BLOCK_TABLE.TP_LIST = reshape( BLOCK_TABLE.TP_LIST, [], 1);
BLOCK_TABLE.CATCH_TP_LIST = reshape( BLOCK_TABLE.CATCH_TP_LIST, [], 1);
OUTPUT{numel(OUTPUT)+1} = 'BLOCK_TABLE';

TP_TABLE = rmfield(data(1).TP_TABLE, {'COLUMN_ORDER', 'USED', 'DESCRIPTIONS'});
OUTPUT{numel(OUTPUT)+1} = 'TP_TABLE';



%=============================
% TRIAL INFO
%=============================

ntrials = numel(data);

nt = 0;
for t = 1:ntrials; nt = nt + get_frame_count(data(t).HAND); end
[timestamps, trial, values] = deal(nan(nt, 1));


TRIAL_DATA = struct();
TRIAL_DATA.trial = uint16((1:ntrials)');
TRIAL_DATA.n_timestamps = uint16(zeros(ntrials,1));
TRIAL_DATA.time = cell(ntrials,1);
TRIAL_DATA.is_error = uint8(zeros(ntrials,1));
TRIAL_DATA.tp_row = uint16(zeros(ntrials,1));

if isfield(data(1), 'EVENTS')
    eventsExist = true;
    [~, tags] = sortEvents(data(1));

    headers = [...
        cellfun(@(x) cat(2,'EVENT_TIME_SEC_',x), tags, 'UniformOutput', 0);...
        cellfun(@(x) cat(2,'EVENT_TIMESTAMP_',x), tags, 'UniformOutput', 0);...
        cellfun(@(x) cat(2,'EVENT_ORDER_',x), tags, 'UniformOutput', 0)];
    headers = cellfun(@(x) matlab.lang.makeValidName(x), headers, 'UniformOutput', 0);
    for h = 1:numel(headers); TRIAL_DATA.(headers{h}) = nan(ntrials,1); end
else
    eventsExist = false;
end

row_i = 1;

for t = 1:ntrials
    nt = get_frame_count(data(t).HAND);
    
    row_j = row_i + nt - 1;
    timestamps(row_i:row_j) = 1:nt;
    trial(row_i:row_j) = repmat(t, nt, 1);

    TRIAL_DATA.n_timestamps(t) = uint16(nt);
    TRIAL_DATA.time{t} = data(t).TRIAL.TIME(1:8);
    TRIAL_DATA.is_error(t) = uint8(data(t).TRIAL.IS_ERROR);
    TRIAL_DATA.tp_row(t) = uint16(data(t).TRIAL.TP);
    
    if eventsExist
        events = reshape( sortEvents(data(t)), [], 1);
        for h = 1:numel(headers)
            TRIAL_DATA.(headers{h})(t) = events(h);
        end
    end
    
    row_i = row_j + 1;
end




%=============================
% TIME SERIES DATA
%=============================

fnames = fieldnames(data(1));
nfields = numel(fnames);
TIME_SERIES_DATA = struct('timestamp', uint16(timestamps), 'trial', uint16(trial));

for f = 1:nfields
    row_i = 1;
    fname = fnames{f};
    
    % check if time series
    if strcmpi(class(data(1).(fname)), 'double') % &&...
            % ~startsWith(fname, 'Left_') &&...
            % ~startsWith(fname, 'Gaze_')
        
        for t = 1:ntrials
            nt = get_frame_count(data(t).HAND);
            row_j = row_i + nt - 1;
            values(row_i:row_j) = data(t).(fname);
            row_i = row_j + 1;
        end
        
        TIME_SERIES_DATA.(fname) = compress(values);
        
    end
end


%=============================
% SAVE DATA INTO A (TEMPORARY) .MAT FILE
%=============================
outputname = regexprep(data_in.file_name, '.zip', '.mat');
save(outputname,'TIME_SERIES_DATA', 'TRIAL_DATA', 'SESSION_DATA', OUTPUT{:})


end



function content = compress(content)

original_class = class(content);
classtypes = {'double'; 'single'; 'int64'; 'int32'; 'int16'; 'int8';...
    'uint64'; 'uint32'; 'uint16'; 'uint8'};
k = find(strcmpi(classtypes, original_class)) + 1;

while k <= numel(classtypes)
    % compress data one classtype above
    compressed_content = cast(content, classtypes{k});
    if strcmpi(class(content),'double')
        abs_err = abs(compressed_content - content);
    else
        % to allow comparisons across int classes
        decompressed_content = cast(compressed_content, original_class);
        abs_err = abs(decompressed_content - content);
    end
    
    max_abs_err = max(abs_err(:));

    if max_abs_err == 0
        content = compressed_content;
        original_class = class(content);
    else
        k = numel(classtypes) + 1;  % break the loop
    end
    k = k + 1;
end

end


function [events, event_names] = sortEvents(data)

samplerate = data.ANALOG.RATE;
occured_events = cellfun(@(x) deblank(x), data.EVENTS.LABELS ,'uniformoutput',false)';% Remove whitespaces
event_names = data.EVENT_DEFINITIONS.LABELS';% Get all the possible events
n_event = length(event_names);
events = nan(n_event,3);

for m = 1:n_event
    
    event_order = find(strcmpi(event_names(m),occured_events)); % order of occurence

    if ~isempty(event_order)                    % If event does exist...
        time = data.EVENTS.TIMES(event_order);  %...find its time in sec...
        index = round(time * samplerate);       % index of event occurrence
        events(m,:) = [ time(end), index(end), event_order(end) ]; % take last occurence if several
    end
end


end


function frame_count = get_frame_count(S)
if isfield(S, 'LONG_FRAMES')
    frame_field = 'LONG_FRAMES';
else
    frame_field = 'FRAMES';
end
frame_count = S.(frame_field);
end


















