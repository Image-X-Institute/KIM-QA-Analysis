function ConvertRobot2Hexamotion

[fname, pname] = uigetfile;
% pname = 'E:\GitHub\KIM-QA-Analysis\Robot traces';
% fname = 'LiverTraj_BaselineWanderWithCardiac70s_robot.txt';

fid = fopen([pname '\' fname]);
rawMotionData = textscan(fid, '%f %f %f %f %f %f %f');
time = rawMotionData{1};
position = [rawMotionData{2} rawMotionData{3} rawMotionData{4}];
fclose(fid);

hexatime = 0:0.02:time(end);

posx = interp1(time,position(:,1),hexatime,'linear');
posy = interp1(time,position(:,2),hexatime,'linear');
posz = interp1(time,position(:,3),hexatime,'linear');

fid = fopen([pname '\hexa_' fname], 'w+');
fprintf(fid,'%s\n',['trajectory']);
fprintf(fid,'%.6f\t%.6f\t%.6f\r\n', [posx posy posz]');
fclose(fid);
