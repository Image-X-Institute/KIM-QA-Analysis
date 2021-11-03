function AnalyseKIMqa(KIMdata)
% AnalyseKIMqa(KIM);
%
% Purpose: Analyse KIM log files acquired during routine QA and compare
%   with the delivered motion files
% Use: Intended for use solely through the UI developed for KIM QA analysis
% Requirements: KIM variable produced by UI
%
% Authors: Jin, Chandrima Sengupta, Jonathan Hindmarsh
% Ver: Aug 2021
% Changes: combine dynamic, treatment interlock, Varian and Elekta versions
%   into one program with common modules and functions

%% setup internal variables
noti_fid = msgbox('Processing, please wait');

switch KIMdata.type
    case 'static'
        static = 1;
        append = 'Static';
    case 'dynamic'
        static = 0;
        append = 'Dynamic';
    case 'interrupt'
        static = 0;
        append = 'Interrupt';
end

% Find KIM trajectory log files in the specified folder
listOfTrajFiles = ls([KIMdata.KIMTrajFolder '\*GA*.txt']);
for n = size(listOfTrajFiles,1):-1:1
   if contains(listOfTrajFiles(n,:), 'ol', 'IgnoreCase', true)
       listOfTrajFiles(n,:) = [];
   end
end
noOfTrajFiles = size(listOfTrajFiles,1);

% Create output file name
prefix = datestr(now, 'yymmdd-HHMM');
if static
    [~, RobotFile, ~] = fileparts(KIMdata.KIMTrajFolder);
    middle = RobotFile;
else
    [~, RobotFile, ~] = fileparts(KIMdata.KIMRobotFile);
    if length(RobotFile)<20
        middle = RobotFile;
    else
        middle = RobotFile(1:20);
    end
end
file_output = [prefix '_' middle '_' append '.txt'];
file_output = fullfile(KIMdata.KIMOutputFolder, file_output);

% Original code included a latency value of either 0.2 (Dyn) or 0.35 (TxInt)
%   No documentation regarding source or reason for this value was included
%   and there was also no reason for a difference between the values used
latency = 0;

%% Read coordinate file
% First column x (RL), second column y (AP), third column z (IS)
% First 'n' rows are marker co-ordinates
% Last row is the isocentre

coordData = KIMCoordinate(KIMdata.KIMcoordFile);

nMar = size(coordData,1)-1;

marker_x = sum(coordData(1:end-1,1))/nMar;
marker_y = sum(coordData(1:end-1,2))/nMar;
marker_z = sum(coordData(1:end-1,3))/nMar;

% Marker co-ordinates need to be transformed to machine space (Dicom to IEC)
% In IEC space y is inverted and y and z are switched
Avg_marker_x = 10*(marker_x - coordData(end,1));
Avg_marker_y = 10*(marker_z - coordData(end,3));
Avg_marker_z = -10*(marker_y - coordData(end,2));


%% Read and extract motion data
% accepts both Robot 6DOF file and Hexamotion 3 DOF files

if static
    % dataMotion.raw = [lateral(x) longitudinal(y) vertical(z)]
    if strcmp(KIMdata.vendor,'Varian')
        dataMotion.raw = [KIMdata.value_LR KIMdata.value_SI -KIMdata.value_AP];
    else
        dataMotion.raw = [KIMdata.value_LR KIMdata.value_SI KIMdata.value_AP];
    end
else
    fid = fopen(KIMdata.KIMRobotFile);
    FirstLine = fgetl(fid);
    if ~isnumeric(FirstLine) && FirstLine(1)=='t'
        % Hexamotion trajectory files start with 'trajectory'
        isrobot = 0;
        % Remainder of data is 3 columns of mm values specifying:
        %   LR|IS|PA
        %   where R, S, & A are positive
        rawMotionData = textscan(fid, '%f %f %f');
    else
        % Robot trajectory files have no header and *should* start with '0'
        isrobot = 1;
        frewind(fid);
        % Robot data file has 7 columns of data:
        %   Time|x|y|z|rotx|roty|rotz
        %   Time is in seconds, position in mm, rotation in degrees
        %   Directions as per IEC 1217 definition
        rawMotionData = textscan(fid, '%f %f %f %f %f %f %f');
    end
    fclose(fid);
    
    if isrobot
        % Robot files are specified in IEC1217 format which is what the rest of
        %   the analysis expects so no adjustment necessary
        dataMotion.raw = [rawMotionData{2} rawMotionData{3} rawMotionData{4}];
        
        dataMotion.timestamps = rawMotionData{1};
    else
        % Hexamotion co-ordinates need to be adapted to fit IEC definition
        %   specifically the x direction needs to be inverted so that L is pos+
        dataMotion.raw = [-1.*rawMotionData{1} rawMotionData{2} rawMotionData{3}];
        
        % Hexa_freq = 0.0225; % According to hexamotion documentation, this is meant to be 0.02, however 0.0225 fits the KIM data better
        Hexa_freq = 0.02;
        
        dataMotion.timestamps = [0:Hexa_freq:(length(rawMotionData{1})-1)*Hexa_freq]';
    end
end

%% Read couchshift file
if exist(fullfile(KIMdata.KIMTrajFolder, 'couchShifts.txt'),'file') == 2
    fid=fopen(fullfile(KIMdata.KIMTrajFolder, 'couchShifts.txt'));
    couch.Positions = textscan(fid, '%f,%f,%f\r', 'headerlines', 1);
    fclose(fid);
    
    couch.vrt = couch.Positions{1};
    couch.lng = couch.Positions{2};
    couch.lat = couch.Positions{3};
    couch.lat(couch.lat>950) = couch.lat(couch.lat>950) - 1000;
    
    couch.NumShifts = length(couch.vrt)-1;
    if strcmp(KIMdata.vendor,'Varian')
%         couch.ShiftsAP = -diff(couch.vrt)*10;	% AP maps to couch -vert
        couch.ShiftsAP = diff(couch.vrt)*10;	% AP maps to couch -vert
        couch.ShiftsSI = diff(couch.lng)*10;    % SI maps to couch long
        couch.ShiftsLR = diff(couch.lat)*10;    % LR maps to couch lat
    else
        couch.ShiftsAP = diff(couch.vrt)*10;	% AP maps to couch vert
        couch.ShiftsSI = diff(couch.lng)*10;    % SI maps to couch long
        couch.ShiftsLR = diff(couch.lat)*10;    % LR maps to couch lat
    end
else
    couch.NumShifts = 0;
end

%% Read and extract KIM trajectory data
% opts = delimitedTextImportOptions('Delimiter',',');
% opts = detectImportOptions(fullfile(KIMdata.KIMTrajFolder, listOfTrajFiles(1,:)));

if noOfTrajFiles > 1
    rawDataKIM = cell(noOfTrajFiles,1);
    for traj = 1:noOfTrajFiles
%         if strcmpi(listOfTrajFiles(traj,end-5),'0')
%             opts.VariableNamesLine = 1; % first line contains varaiable descriptions
%             opts.DataLines = 2;  % for the first KIM data file, the data starts on the second line (after the header row)
%         else
%             opts.VariableNamesLine = 0; % first line contains varaiable descriptions
%             opts.DataLines = 1; % for subsequent KIM data files the data starts on the first line
%         end
        logfilename = fullfile(KIMdata.KIMTrajFolder, listOfTrajFiles(traj,:));
        opts = detectImportOptions(logfilename);
        temp = readcell(logfilename, opts);
        if traj == 1
            NumCol = size(temp,2);
            rawDataKIM{traj} = temp;
            clear temp
        else
            rawDataKIM{traj} = temp(:,1:NumCol);
            clear temp
        end
    end
    ShiftIndex_KIM = cellfun('size',rawDataKIM,1);
    ShiftIndex_KIM = cumsum(ShiftIndex_KIM);
    
    rawDataKIM = vertcat(rawDataKIM{:});
else
    logfilename = fullfile(KIMdata.KIMTrajFolder, listOfTrajFiles);
    opts = detectImportOptions(logfilename);
    rawDataKIM = readcell(logfilename, opts);
end

dataKIM.time.raw = [rawDataKIM{:,2}]';
dataKIM.time.raw = dataKIM.time.raw - dataKIM.time.raw(1);
dataKIM.Gantry = [rawDataKIM{:,3}]';
dataKIM.index = [rawDataKIM{:,1}]';

% Calculate the number of arcs by looking at the change in gantry rotation
%   Make gantry angles in the file continuous
%   Calculate the change in gantry angle between points
%   Sum the number of times this changes sign (ie rotation direction)
%   Add one to give the number of arcs
KIMdata.NumArcs = sum(abs(diff(diff(dataKIM.Gantry(dataKIM.Gantry<90)+360)>0)))+1;

% Determine the index for treatment start
[~, d_index] = sort(diff(dataKIM.time.raw),'descend');
indexOfTreatStart = min(d_index(1:KIMdata.NumArcs)) + 1;
dataKIM.indexOfTreatStart = indexOfTreatStart;

%% Trajectories for KIM data
% Index the markers by SI position where 1 is the most cranial and 3 the most caudal
% Note: for Varian kV panels x-y origin appears to be top-left of panel
%   (from source persepective); meaning lower y values are more superior

[~, index] = sort([rawDataKIM{1,6:3:3+3*nMar}], 'descend');

for n = 1:nMar
    dataKIM.coord.raw.x(:,n) = [rawDataKIM{:,3+3*(index(n)-1)+2}]';   % LR maps to x
    dataKIM.coord.raw.y(:,n) = [rawDataKIM{:,3+3*(index(n)-1)+3}]';   % SI maps to y
    dataKIM.coord.raw.z(:,n) = [rawDataKIM{:,3+3*(index(n)-1)+1}]';   % AP maps to z
    
    % C# indexes from 0 to N-1 so a + 1 is added to each 2D trajectory for
    %	equivalent comparison to MATLAB
    dataKIM.pixel.raw.x(:,n) = [rawDataKIM{:,(3+3*nMar)+2*(index(n)-1)+1}]' + 1;
    dataKIM.pixel.raw.y(:,n) = [rawDataKIM{:,(3+3*nMar)+2*(index(n)-1)+2}]' + 1;
end

% Compute centroid for the 2D coordinates
dataKIM.pixel = [sum(dataKIM.pixel.raw.x,2)/nMar sum(dataKIM.pixel.raw.y,2)/nMar];

dataKIM.coord.center(:,1) = sum(dataKIM.coord.raw.x,2)/nMar - Avg_marker_x;
dataKIM.coord.center(:,2) = sum(dataKIM.coord.raw.y,2)/nMar - Avg_marker_y;
dataKIM.coord.center(:,3) = sum(dataKIM.coord.raw.z,2)/nMar - Avg_marker_z;

%% Remove couch shifts from KIM
dataKIM.coord.shifted = dataKIM.coord.center;
if couch.NumShifts >= 1
    for n = 1:couch.NumShifts
        % x maps to LR couch; y maps to SI couch; z maps to AP couch
        dataKIM.coord.shifted(ShiftIndex_KIM(n):end,:) = dataKIM.coord.center(ShiftIndex_KIM(n):end,:) - [couch.ShiftsLR(n) couch.ShiftsSI(n) couch.ShiftsAP(n)];
    end
end
if static
    dataKIM.coord.shifted = dataKIM.coord.shifted(10:end,:);
    AnalyseStatic(dataKIM, dataMotion, file_output, couch.NumShifts>=1);
    if exist('noti_fid', 'var')
        delete(noti_fid);
        clear('noti_fid');
    end
    return
end

%% Align KIM and motion traces
app = ManualMatch(dataKIM, dataMotion);  % create the matching app window
while app.Done == 0  % polling
    pause(0.05);
end
if app.Done == -1
   return
end
TimeShift = app.GrossSlider.Value + app.FineSlider.Value;
SourceMotion = app.data.Source;
KIMmagnitude = app.data.Compare;
app.CloseThisWindow;   % delete the parameter window

dataKIM.time.corrected = dataKIM.time.raw + TimeShift + latency;
ZeroIndex = find(dataKIM.time.corrected>0,1,'first');

%% Add couch shifts to source motion
dataMotion.shifted = dataMotion.raw;
if couch.NumShifts >= 1
    for n = 1:couch.NumShifts
        [~,ShiftIndex_Mot(n)] = min(abs(dataMotion.timestamps - dataKIM.time.corrected(ShiftIndex_KIM(n))));
        % x maps to LR couch; y maps to SI couch; z maps to AP couch
        dataMotion.shifted(ShiftIndex_Mot(n):end,:) = dataMotion.raw(ShiftIndex_Mot(n):end,:) + [couch.ShiftsLR(n) couch.ShiftsSI(n) couch.ShiftsAP(n)];
    end
end

%% Results and Output

dataKIM.time.treat = dataKIM.time.corrected(dataKIM.indexOfTreatStart:end);
dataKIM.coord.treat = dataKIM.coord.center(dataKIM.indexOfTreatStart:end,:);

% Interpolate source motion to match KIM timepoints and ensure there are no
%   NaN values
% Timepoints corresponding to entire collected KIM data (pre-arc + treatment)
dataMotion.interp(:,1) = fillmissing(interp1(dataMotion.timestamps, dataMotion.shifted(:,1), dataKIM.time.corrected),'nearest');
dataMotion.interp(:,2) = fillmissing(interp1(dataMotion.timestamps, dataMotion.shifted(:,2), dataKIM.time.corrected),'nearest');
dataMotion.interp(:,3) = fillmissing(interp1(dataMotion.timestamps, dataMotion.shifted(:,3), dataKIM.time.corrected),'nearest');

% Timepoints corresponding to KIM data during treatment
dataMotion.treat(:,1) = fillmissing(interp1(dataMotion.timestamps, dataMotion.shifted(:,1), dataKIM.time.treat),'nearest');
dataMotion.treat(:,2) = fillmissing(interp1(dataMotion.timestamps, dataMotion.shifted(:,2), dataKIM.time.treat),'nearest');
dataMotion.treat(:,3) = fillmissing(interp1(dataMotion.timestamps, dataMotion.shifted(:,3), dataKIM.time.treat),'nearest');

% *For treatment only*
% Calculate the difference between KIM detected position and expected
%   position as specified by the motion source
% For ease of data processing rearrange positional data into column: x(LR), y(SI), z(AP)
dataKIM.analysis.TxMotionDiff = dataKIM.coord.treat - dataMotion.treat;

% Calculate mean, stdev and percentile for the positinal data
dataKIM.analysis.TxResults{1,:} = mean(dataKIM.analysis.TxMotionDiff,1);
dataKIM.analysis.TxResults{2,:} = std(dataKIM.analysis.TxMotionDiff,0,1);
dataKIM.analysis.TxResults{3,:} = tsprctile(dataKIM.analysis.TxMotionDiff,[5 95],1);

% *For all acquired KIM data (including prearc data)*
% Repeat above
% For ease of data processing rearrange positional data into column: x(LR), y(SI), z(AP)
dataKIM.analysis.MotionDiff = dataKIM.coord.center - dataMotion.interp;
dataKIM.analysis.AbsMotionDiff = sqrt(sum(dataKIM.coord.center.^2,2)) - sqrt(sum(dataMotion.interp.^2,2));

% Calculate mean, stdev and percentile for the positinal data
dataKIM.analysis.AllResults{1,:} = mean(dataKIM.analysis.MotionDiff,1);
dataKIM.analysis.AllResults{2,:} = std(dataKIM.analysis.MotionDiff,0,1);
dataKIM.analysis.AllResults{3,:} = tsprctile(dataKIM.analysis.MotionDiff,[5 95],1);

[dataKIM.analysis.ClippedMotionDiff, dataKIM.analysis.Outliers] = rmoutliers(dataKIM.analysis.AbsMotionDiff, 'median');
if any(dataKIM.analysis.Outliers)
    dataKIM.analysis.ClippedResults{1,:} = mean(dataKIM.analysis.MotionDiff(~dataKIM.analysis.Outliers,:),1);
    dataKIM.analysis.ClippedResults{2,:} = std(dataKIM.analysis.MotionDiff(~dataKIM.analysis.Outliers,:),0,1);
    dataKIM.analysis.ClippedResults{3,:} = tsprctile(dataKIM.analysis.MotionDiff(~dataKIM.analysis.Outliers,:),[5 95],1);
end

failname = {' LR,', ' SI,', ' AP,'};
if any(abs([dataKIM.analysis.AllResults{1,:}])>1)
    OutputText{1,1} = ['QA result: KIM FAILED in ', append, ' test'];
    OutputText{2,1} = ['Tested trajectory ', RobotFile, ': mean difference of',]; 
    OutputText{2,1} = [OutputText{2,1} failname{[dataKIM.analysis.AllResults{1,:}]>1} ' > or = 2 mm' newline];
elseif any([dataKIM.analysis.AllResults{2,:}]>2)
    OutputText{1,1} = ['QA result: KIM FAILED in ', append, ' test'];
    OutputText{2,1} = ['Tested trajectory ', RobotFile, ': standard deviation of difference of',]; 
    OutputText{2,1} = [OutputText{2,1} failname{[dataKIM.analysis.AllResults{2,:}]>2} ' > or = 2 mm' newline];
else
    OutputText{1,1} = ['QA result: KIM PASSED in ', append, ' test'];
    OutputText{2,1} = ['Tested trajectory ' RobotFile newline]; 
end

OutputText{3,1} = sprintf('No. of couch shifts: %u\n', couch.NumShifts);
OutputText{4,1} = sprintf('Processing time per image (Online): %.3f\n', mean(diff(dataKIM.time.raw)));
OutputText{5,1} = sprintf('Mean\t\t\tStd\t\t\tPercentile(5,95)');
OutputText{6,1} = sprintf('LR\tSI\tAP\tLR\tSI\tAP\tLR\tSI\tAP');
OutputText{7,1} = sprintf('%1.2f\t%1.2f\t%1.2f\t%1.2f\t%1.2f\t%1.2f\t(%1.2f, %1.2f)\t(%1.2f, %1.2f)\t(%1.2f, %1.2f)', ...
                    [dataKIM.analysis.AllResults{1,:}], [dataKIM.analysis.AllResults{2,:}], [dataKIM.analysis.AllResults{3,:}]);
OutputText{8,1} = newline;
OutputText{9,1} = sprintf('Time shift to match motion traces is = %.4g seconds', TimeShift);

if any(dataKIM.analysis.Outliers)
    OutputText{10,1} = newline;
    OutputText{11,1} = [newline '---------------------------------'];
    OutputText{12,1} = sprintf('%u outliers detected in KIM trace', sum(dataKIM.analysis.Outliers));
    OutputText{13,1} = 'Results when outliers removed are:';
    OutputText{14,1} = sprintf('Mean\t\t\tStd\t\t\tPercentile(5,95)');
    OutputText{15,1} = sprintf('LR\tSI\tAP\tLR\tSI\tAP\tLR\tSI\tAP');
    OutputText{16,1} = sprintf('%1.2f\t%1.2f\t%1.2f\t%1.2f\t%1.2f\t%1.2f\t(%1.2f, %1.2f)\t(%1.2f, %1.2f)\t(%1.2f, %1.2f)', ...
        [dataKIM.analysis.ClippedResults{1,:}], [dataKIM.analysis.ClippedResults{2,:}], [dataKIM.analysis.ClippedResults{3,:}]);
end

writecell(OutputText,file_output, 'Delimiter','space', 'QuoteStrings', false)

%% Plots
% Plot basic KIM x-y-z data
figure, plot(dataKIM.time.raw, dataKIM.coord.shifted(:,1), 'bx', dataKIM.time.raw, dataKIM.coord.shifted(:,2), 'gx', dataKIM.time.raw, dataKIM.coord.shifted(:,3), 'rx')
ylabel('Position (mm)', 'fontsize',16);
xlabel('Time (s)', 'fontsize',16);
title('KIM 3DoF motion', 'fontsize', 16);
legend('LR (KIM)', 'SI (KIM)', 'AP (KIM)', 'Location', 'best');
set(gca,'fontsize',16)

if couch.NumShifts >= 1
    % Plot KIM SI with couch shifts
    f = figure;
    hold on
    plot(dataKIM.coord.center(:,2), 'g.', 'linewidth', 3)
    xlabel('Index', 'fontsize',16)
    ylabel('SI position (mm)', 'fontsize',16)
    title('Step 1: KIM with couch shifts', 'fontsize', 16)
    set(gca,'fontsize',16)
    hold off
    ImageFilename = [prefix '_' middle '_KIM_Source Step 1 - with shifts.jpg'];
    print(f,'-djpeg','-r300',fullfile(KIMdata.KIMOutputFolder,ImageFilename))
    
    % Plot KIM SI corrected for couch shifts
    f = figure;
    hold on
    plot(dataKIM.coord.shifted(:,2), 'g.', 'linewidth', 3)
    xlabel('Index', 'fontsize',16)
    ylabel('SI position (mm)', 'fontsize',16)
    title('Step 2: KIM with couch shifts undone', 'fontsize', 16)
    set(gca,'fontsize',16)
    hold off
    ImageFilename = [prefix '_' middle '_KIM_Source Step 2 - shifts undone.jpg'];
    print(f,'-djpeg','-r300',fullfile(KIMdata.KIMOutputFolder,ImageFilename))
    
    % Plot KIM with expected motion data (matched)
    f = figure('Units','pixels','Position',[100 100 1000 600]);
    hold on
    plot(dataMotion.timestamps, dataMotion.raw(:,2), 'k-', dataKIM.time.corrected(ZeroIndex:end), dataKIM.coord.shifted(ZeroIndex:end,2), 'g.')
    xlabel('Index', 'fontsize',16)
    ylabel('SI position (mm)', 'fontsize',16)
    title('Step 3: KIM after time shift; no couch shifts', 'fontsize', 16)
    set(gca,'fontsize',16)
    hold off
    ImageFilename = [prefix '_' middle '_KIM_Source Step 3 - after time shift.jpg'];
    print(f,'-djpeg','-r300',fullfile(KIMdata.KIMOutputFolder,ImageFilename))
else
%     figure, plot(dataKIM.coord.shifted(:,2), 'g.', 'linewidth', 3)
%     xlabel('Index', 'fontsize',16)
%     ylabel('SI position (mm)', 'fontsize',16)
%     title('KIM SI trace', 'fontsize', 16)
%     set(gca,'fontsize',16)
end

% Plot KIM synced with expected motion data
f = figure('Units','pixels','Position',[100 100 1000 600]);
hold on
plot(dataMotion.timestamps, SourceMotion, 'k.', dataKIM.time.raw + TimeShift, KIMmagnitude, 'r-')
plot(dataMotion.timestamps, sqrt(sum(dataMotion.raw.^2,2)), 'c--', dataKIM.time.raw + TimeShift, sqrt(sum(dataKIM.coord.shifted.^2,2)), 'g--')
xlabel('Index', 'fontsize',16)
ylabel('Position (mm)', 'fontsize',16)
title('Smoothed source motion vs KIM detected motion', 'fontsize', 16)
legend('Smoothed Source', 'Smoothed KIM', 'Source', 'KIM', 'Location', 'best');
set(gca,'fontsize',16)
hold off
ImageFilename = [prefix '_' middle '_KIM_Source_synced.jpg'];
print(f,'-djpeg','-r300',fullfile(KIMdata.KIMOutputFolder,ImageFilename))

f = figure('Units','pixels','Position',[100 100 1000 600]);
hold on
plot(dataKIM.time.corrected(ZeroIndex:end), dataKIM.coord.center(ZeroIndex:end,2),'gx', dataKIM.time.corrected(ZeroIndex:end), dataKIM.coord.center(ZeroIndex:end,3),'rx', dataKIM.time.corrected(ZeroIndex:end), dataKIM.coord.center(ZeroIndex:end,1),'bx', 'linewidth', 3)
plot(dataMotion.timestamps, dataMotion.shifted(:,2),'g-', dataMotion.timestamps, dataMotion.shifted(:,3),'r-', dataMotion.timestamps, dataMotion.shifted(:,1),'b-')
ylabel('Position (mm)', 'fontsize',16);
xlabel('Time (s)', 'fontsize',16);
title('KIM vs Source motion', 'fontsize', 16);
legend('SI (KIM)', 'AP (KIM)', 'LR (KIM)', 'SI (Actual)', 'AP (Actual)', 'LR (Actual)','Location', 'best' );
set(gca,'fontsize',16)
hold off
ImageFilename = [prefix '_' middle '_KIMvsMotion.jpg'];
print(f,'-djpeg','-r300',fullfile(KIMdata.KIMOutputFolder,ImageFilename))

if any(dataKIM.analysis.Outliers)
    dataKIM.analysis.Outliers(1:ZeroIndex-1) = 1;
    f = figure('Units','pixels','Position',[100 100 1000 600]);
    hold on
    plot(dataKIM.time.corrected(~dataKIM.analysis.Outliers), dataKIM.coord.center(~dataKIM.analysis.Outliers,2),'gx', ...
        dataKIM.time.corrected(~dataKIM.analysis.Outliers), dataKIM.coord.center(~dataKIM.analysis.Outliers,3),'rx', ...
        dataKIM.time.corrected(~dataKIM.analysis.Outliers), dataKIM.coord.center(~dataKIM.analysis.Outliers,1),'bx', 'linewidth', 3)
    plot(dataMotion.timestamps, dataMotion.shifted(:,2),'g-', ...
        dataMotion.timestamps, dataMotion.shifted(:,3),'r-', ...
        dataMotion.timestamps, dataMotion.shifted(:,1),'b-')
    ylabel('Position (mm)', 'fontsize',16);
    xlabel('Time (s)', 'fontsize',16);
    title('KIM vs Source motion (outliers removed)', 'fontsize', 16);
    legend('SI (KIM)', 'AP (KIM)', 'LR (KIM)', 'SI (Actual)', 'AP (Actual)', 'LR (Actual)','Location', 'best' );
    set(gca,'fontsize',16)
    hold off
    ImageFilename = [prefix '_' middle '_KIMvsMotion_clipped.jpg'];
    print(f,'-djpeg','-r300',fullfile(KIMdata.KIMOutputFolder,ImageFilename))
end

if exist('noti_fid', 'var')
  delete(noti_fid);
  clear('noti_fid');
end

end


function StartingIndex=StrtIndx(KIMmotion)
    corr_mag = KIMmotion - min(KIMmotion);
    motion_diff = diff(KIMmotion);
    diffSD = std(motion_diff);
    
    corr_mag = corr_mag<1;
    motion_diff = motion_diff<2*diffSD;
    
    StartingIndex = find(and(corr_mag(2:end), motion_diff),1)+1;
    if isempty(StartingIndex)
        StartingIndex = 1;
    elseif StartingIndex > 50
        StartingIndex = 50;
    end
end

function AnalyseStatic(dataKIM, dataMotion, file_output, couchshifted)
% dataMotion.raw [LR, SI, AP] couch shifts
% dataKIM.coord.shifted [x, y, z] KIM data

f = figure;
hold on
plot(dataKIM.time.raw(10:end), dataKIM.coord.shifted(:,1), 'bx', dataKIM.time.raw(10:end), dataKIM.coord.shifted(:,2), 'gx', dataKIM.time.raw(10:end), dataKIM.coord.shifted(:,3), 'rx')
ylabel('Position (mm)', 'fontsize',16);
xlabel('Time (s)', 'fontsize',16);
title('KIM 3DoF motion', 'fontsize', 16);
legend('LR (KIM)', 'SI (KIM)', 'AP (KIM)', 'Location', 'best');
set(gca,'fontsize',16)
hold off
ImageFilename = [file_output(1:end-4) '.jpg'];
print(f,'-djpeg','-r300',ImageFilename)

if couchshifted
    f = figure;
    hold on
    plot(dataKIM.time.raw, dataKIM.coord.center(:,1), 'bx', dataKIM.time.raw, dataKIM.coord.center(:,2), 'gx', dataKIM.time.raw, dataKIM.coord.center(:,3), 'rx')
    ylabel('Position (mm)', 'fontsize',16);
    xlabel('Time (s)', 'fontsize',16);
    title('KIM 3DoF motion (no couch shifts applied)', 'fontsize', 16);
    legend('LR (KIM)', 'SI (KIM)', 'AP (KIM)', 'Location', 'best');
    set(gca,'fontsize',16)
    hold off
    ImageFilename = [file_output(1:end-4) '_unshifted.jpg'];
    print(f,'-djpeg','-r300',ImageFilename)
end

DisplacementMean = mean(dataKIM.coord.shifted - dataMotion.raw,1);
DisplacementStd = std(dataKIM.coord.shifted - dataMotion.raw,1);
DisplacementPct = tsprctile(dataKIM.coord.shifted - dataMotion.raw,[5 95],1);

failname = {' LR,', ' SI,', ' AP,'};
if any(abs(DisplacementMean)>1)
    OutputText{1,1} = 'QA result: KIM FAILED in Static test';
    OutputText{2,1} = 'Tested static move: mean difference of'; 
    OutputText{2,1} = [OutputText{2,1} failname{DisplacementMean>1} ' > or = 2 mm' newline];
elseif any(DisplacementStd>2)
    OutputText{1,1} = 'QA result: KIM FAILED in Static test';
    OutputText{2,1} = 'Tested staic move: standard deviation of difference of'; 
    OutputText{2,1} = [OutputText{2,1} failname{DisplacementStd>2} ' > or = 2 mm' newline];
else
    OutputText{1,1} = 'QA result: KIM PASSED in Static test';
    OutputText{2,1} = ['Tested static movement' newline]; 
end

OutputText{3,1} = sprintf('Mean\t\t\tStd\t\t\tPercentile(5,95)');
OutputText{4,1} = sprintf('LR\tSI\tAP\tLR\tSI\tAP\tLR\tSI\tAP');
OutputText{5,1} = sprintf('%1.2f\t%1.2f\t%1.2f\t%1.2f\t%1.2f\t%1.2f\t(%1.2f, %1.2f)\t(%1.2f, %1.2f)\t(%1.2f, %1.2f)', ...
                    DisplacementMean, DisplacementStd, DisplacementPct);
OutputText{6,1} = newline;

writecell(OutputText,file_output, 'Delimiter','space', 'QuoteStrings', false)
end

function output = KIMCoordinate(inputfile)

    coordData = readcell(inputfile);
    if isnumeric(coordData{1,1})
        output = cell2mat(coordData);
    else
        extract = split(coordData(3:end,2:end),'=');
        output = cellfun(@str2num,extract(:,:,2));
    end
end