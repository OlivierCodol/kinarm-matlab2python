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
% script is called recursively for ech .zip file contained in the directory
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


LOAD_TABLE = rmfield(data(1).LOAD_TABLE, {'COLUMN_ORDER', 'USED', 'DESCRIPTIONS'});

TARGET_TABLE = rmfield(data(1).TARGET_TABLE,...
    {'COLUMN_ORDER', 'USED', 'DESCRIPTIONS', 'FRAME_OF_REFERENCE', 'FRAME_OF_REFERENCE_LIST'});
TARGET_TABLE.Text_String = reshape( TARGET_TABLE.Text_String, [], 1);

BLOCK_TABLE = rmfield(data(1).BLOCK_TABLE, {'USED', 'DESCRIPTIONS'});
BLOCK_TABLE.TP_LIST = reshape( BLOCK_TABLE.TP_LIST, [], 1);
BLOCK_TABLE.CATCH_TP_LIST = reshape( BLOCK_TABLE.CATCH_TP_LIST, [], 1);

TP_TABLE = rmfield(data(1).TP_TABLE, {'COLUMN_ORDER', 'USED', 'DESCRIPTIONS'});



%=============================
% TRIAL INFO
%=============================

ntrials = numel(data);
block_lims = sortBlockTable(data(1));

nt = 0;
for t = 1:ntrials; nt = nt + data(t).HAND.FRAMES; end
[timestamps, trial, values] = deal(nan(nt, 1));


TRIAL_DATA = struct();
TRIAL_DATA.block = uint16(zeros(ntrials,1));
TRIAL_DATA.trial = uint16((1:ntrials)');
TRIAL_DATA.n_timestamps = uint16(zeros(ntrials,1));
TRIAL_DATA.time = cell(ntrials,1);
TRIAL_DATA.is_error = uint8(zeros(ntrials,1));
TRIAL_DATA.tp_row = uint16(zeros(ntrials,1));


[~, tags] = sortEvents(data(t));

headers = [...
    cellfun(@(x) cat(2,'EVENT_TIMESTAMP_',x), tags, 'UniformOutput', 0);...
    cellfun(@(x) cat(2,'EVENT_TIME_SEC_',x), tags, 'UniformOutput', 0);...
    cellfun(@(x) cat(2,'EVENT_ORDER_',x), tags, 'UniformOutput', 0)];
for h = 1:numel(headers); TRIAL_DATA.(headers{h}) = nan(ntrials,1); end

n_error = 0;
row_i = 1;

for t = 1:ntrials
    is_error = data(t).TRIAL.IS_ERROR==1; % error trials are dumped
    n_error = n_error + is_error;         % count error trials
    nt = data(t).HAND.FRAMES;
    
    row_j = row_i + nt - 1;
    timestamps(row_i:row_j) = 1:nt;
    trial(row_i:row_j) = repmat(t, nt, 1);

    TRIAL_DATA.block(t) = uint16( sum((t-n_error) > cumsum(block_lims))+1 );
    TRIAL_DATA.n_timestamps(t) = uint16(nt);
    TRIAL_DATA.time{t} = data(t).TRIAL.TIME(1:8);
    TRIAL_DATA.is_error(t) = uint8(data(t).TRIAL.IS_ERROR);
    TRIAL_DATA.tp_row(t) = uint16(data(t).TRIAL.TP);
    
    events = reshape( sortEvents(data(t)), [], 1);
    for h = 1:numel(headers)
        TRIAL_DATA.(headers{h})(t) = events(h);
    end

    
    row_i = row_j + 1;
end

if n_error + ntrials ~= sum(block_lims)
    warning('Custom warning: mismatch in count of total trials.')
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
    
    if strcmpi(class(data(1).(fname)), 'double') % &&...
            % ~startsWith(fname, 'Left_') &&...
            % ~startsWith(fname, 'Gaze_')
        
        for t = 1:ntrials
            nt = data(t).HAND.FRAMES;
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
save(outputname,'TIME_SERIES_DATA', 'TRIAL_DATA', 'SESSION_DATA',...
    'LOAD_TABLE', 'TARGET_TABLE', 'BLOCK_TABLE', 'TP_TABLE')


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



function blim = sortBlockTable( data )
% Get how many trials in each block

trials_list         = data.BLOCK_TABLE.TP_LIST;         % trials for this block
trials_rep          = data.BLOCK_TABLE.LIST_REPS;       % trial list repetitions
catch_trials_list   = data.BLOCK_TABLE.CATCH_TP_LIST;   % catch trials for this block
blocks_rep          = data.BLOCK_TABLE.BLOCK_REPS;      % block repetitions

n_blocks = numel(trials_rep);            % how many blocks

if isempty(trials_list);       trials_list       = repmat({''}, n_blocks, 1); end
if isempty(catch_trials_list); catch_trials_list = repmat({''}, n_blocks, 1); end

trial_count = zeros(n_blocks,1);         % count how many normal trials in trial list (for each block)
catch_count = zeros(n_blocks,1);         % count how many catch  trials in catch list (for each block)
instr_trial_count = zeros(n_blocks,1);   % count how many instr. trials in trial list (for each block)
instr_catch_count = zeros(n_blocks,1);   % count how many instr. trials in catch list (for each block)


n_rows = numel(data.TP_TABLE.Load);      % how many rows (one row per trial type)

fnames = fieldnames(data.TP_TABLE);      % columns in TP table
those_cols = find(  contains(fnames,'end','IgnoreCase',true) &...       % columns indicating an end target
                    contains(fnames,'target','IgnoreCase',true)     );

instruct_targ = ~cellfun(@isempty, data.TARGET_TABLE.Text_String);      % targets containing instructions (ie contain text)
instruc_trials = nan( n_rows , numel(those_cols) );                     % allocate memory

for c = 1 : numel(those_cols)                                       % for each end-target column
    trial_targets = data.TP_TABLE.(fnames{those_cols (c)});             % target used in each row
    trial_targets(trial_targets==0) = 1;                                % cannot accept 0s as indices below
    instruc_trials(:,c) = instruct_targ( trial_targets );               % is that target an instruction target?
end


for b = 1:n_blocks
    tprows_trial = sortOneTableLine( trials_list{b}       , n_rows );
    tprows_catch = sortOneTableLine( catch_trials_list{b} , n_rows );

    trial_count(b) = sum( tprows_trial );
    catch_count(b) = sum( tprows_catch );

    instr_trial_count(b) = max( instruc_trials' * tprows_trial ); % find any instruction target among end-target columns
    instr_catch_count(b) = max( instruc_trials' * tprows_catch );
end



% how many instruction trials overall for each block
n_instruct = ((instr_trial_count .* trials_rep) + instr_catch_count) .* blocks_rep;
% how many normal trials overall for each block
blim = ((trial_count .* trials_rep) + catch_count) .* blocks_rep - n_instruct;
% no trial in this block (or no non-instruction trials)
blim(blim==0) = [];


end





function tprows = sortOneTableLine( thistableline , n_rows)

nchara = numel(thistableline);
if nchara==0; nchara=[]; end
commas = strfind(thistableline,',');

chunk_start = 1;
tprows = zeros( n_rows , 1 ); % max number of possible values


for chunk_end = [commas-1, nchara]
    this_chunk = thistableline( chunk_start : chunk_end );
    chunk_start = chunk_end + 2; % for next iteration
    
    dash = strfind(this_chunk, '-');
    if isempty(dash)
        tprow = str2double(this_chunk);
        tprows(tprow) = tprows(tprow) + 1;
    else
        x = str2double(this_chunk(1:dash-1));
        y = str2double(this_chunk(dash+1:end));
        tprows(x:y) = tprows(x:y) + 1;
    end
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




















