classdef AnalyseKIMQA_UI_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        OutputFolderPanel             matlab.ui.container.Panel
        SelectedOutputFolder          matlab.ui.control.EditField
        SelectedfolderLabel_4         matlab.ui.control.Label
        OutputfolderButton            matlab.ui.control.Button
        CoordinateFilePanel           matlab.ui.container.Panel
        SelectedCoordFile             matlab.ui.control.EditField
        SelectedfileEditFieldLabel_6  matlab.ui.control.Label
        FormatxyzspecifiedinEclipseElektaconventionLabel  matlab.ui.control.Label
        ThisisthecoordinatesofthemarkerswithrespecttotheisocentreLabel  matlab.ui.control.Label
        SelectFileButton_2            matlab.ui.control.Button
        KIMlogPanel                   matlab.ui.container.Panel
        SelectedKimFolder             matlab.ui.control.EditField
        SelectedfolderLabel_3         matlab.ui.control.Label
        ThisisfoldercontainingtheKIMgeneratedtrajectoryfilesLabel  matlab.ui.control.Label
        SelectFolderButton            matlab.ui.control.Button
        MotionTracePanel              matlab.ui.container.Panel
        SelectedMotionFile            matlab.ui.control.EditField
        SelectedfileEditFieldLabel_5  matlab.ui.control.Label
        FormattTxTyTzrxryrzLabel      matlab.ui.control.Label
        SelectFileButton              matlab.ui.control.Button
        StaticShiftsmmPanel           matlab.ui.container.Panel
        VertShift                     matlab.ui.control.EditField
        VertAPLabel                   matlab.ui.control.Label
        LongShift                     matlab.ui.control.EditField
        LongSILabel                   matlab.ui.control.Label
        LateralShift                  matlab.ui.control.EditField
        LateralLRLabel                matlab.ui.control.Label
        LinacVendorButtonGroup        matlab.ui.container.ButtonGroup
        ElektaButton                  matlab.ui.control.RadioButton
        VarianButton                  matlab.ui.control.RadioButton
        AnalysistypeButtonGroup       matlab.ui.container.ButtonGroup
        StaticButton                  matlab.ui.control.RadioButton
        TreatmentInterruptButton      matlab.ui.control.RadioButton
        DynamicButton                 matlab.ui.control.RadioButton
        AnalyseButton                 matlab.ui.control.Button
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: SelectFolderButton
        function SelectFolderButtonPushed(app, event)
            global KIM
            if app.SelectedKimFolder.Visible
                folder_name = uigetdir(app.SelectedKimFolder.Value, 'Please select the folder containing MarkerLocation_GA file/s');
            else
                folder_name = uigetdir('C:\', 'Please select the folder containing MarkerLocation_GA file/s');
            end
            if ~isequal(folder_name,0)
                app.SelectedKimFolder.Value = folder_name;
                app.SelectedKimFolder.Visible = 1;
                KIM.KIMTrajFolder=folder_name;
                % Set as output folder as well so that it doesn't need to
                %   be done separately
                app.SelectedOutputFolder.Value = folder_name;
                app.SelectedOutputFolder.Visible = 1;
                KIM.KIMOutputFolder=folder_name;
            end

        end

        % Button pushed function: SelectFileButton
        function SelectFileButtonPushed(app, event)
            global KIM
            if app.SelectedMotionFile.Visible
                [app_path, ~, ~] = fileparts(app.SelectedMotionFile.Value);
                [FileName,PathName,~] = uigetfile([app_path '\*.txt'], 'Please select the motion trajectory file (either Hexamotion or Robot');
            else
                [app_path, ~, ~] = fileparts(mfilename('fullpath'));
                [FileName,PathName,~] = uigetfile([app_path '\*.txt'], 'Please select the motion trajectory file (either Hexamotion or Robot');
            end
            if ~isequal(FileName,0)
                app.SelectedMotionFile.Value = [PathName FileName];
                app.SelectedMotionFile.Visible = 1;
                KIM.KIMRobotFile=[PathName FileName];
            end
        end

        % Callback function
        function SelectCoordinateFileButtonPushed(app, event)

        end

        % Callback function
        function AnalyseButtonPushed(app, event)

        end

        % Button pushed function: SelectFileButton_2
        function SelectFileButton_2Pushed(app, event)
            global KIM
            if app.SelectedCoordFile.Visible
                [prev_path, ~, ~] = fileparts(app.SelectedCoordFile.Value);
                [FileName,PathName,~] = uigetfile([prev_path '\*.txt'], 'Please select the marker co-ordinate file');
            else
                [FileName,PathName,~] = uigetfile('C:\*.txt', 'Please select the marker co-ordinate file');
            end

            if ~isequal(FileName,0)
                app.SelectedCoordFile.Value = [PathName FileName];
                app.SelectedCoordFile.Visible = 1;
                KIM.KIMcoordFile=[PathName FileName];
            end
        end

        % Button pushed function: AnalyseButton
        function AnalyseButtonPushed2(app, event)
            global KIM
            %KIM.handles=handles;
            if ~isfield(KIM, 'vendor')
                selectedButton = app.LinacVendorButtonGroup.SelectedObject;
                if strcmpi(selectedButton.Text,'Varian')
                    KIM.vendor = 'Varian';
                else
                    KIM.vendor = 'Elekta';
                end
            end
            if app.SelectedKimFolder.Visible && app.SelectedCoordFile.Visible && app.SelectedOutputFolder.Visible
                common_components = 1;
            end
            if app.StaticButton.Value
                if common_components && isfield(KIM,'value_AP') && isfield(KIM,'value_LR') && isfield(KIM,'value_SI')
                    KIM.type = 'static';
                    AnalyseKIMqa(KIM)
                else
                    msgbox({'Please set all file and folder locations and the static shifts (enter ''0'' if no shift in that direction)'; 'before clicking analyse'})
                end
            elseif common_components && app.SelectedMotionFile.Visible
                if app.DynamicButton.Value
                    KIM.type = 'dynamic';
                    AnalyseKIMqa(KIM)
                elseif app.TreatmentInterruptButton.Value
                    KIM.type = 'interrupt';
                    AnalyseKIMqa(KIM)
                end

            else
                msgbox('Please set all file and folder locations before clicking analyse')
            end
        end

        % Callback function
        function SelectfileButtonPushed(app, event)

        end

        % Button pushed function: OutputfolderButton
        function OutputfolderButtonPushed(app, event)
            global KIM
            if app.SelectedOutputFolder.Visible
                folder_name = uigetdir(app.SelectedOutputFolder.Value, 'Please select the folder to save the analysis in');
            else
                folder_name = uigetdir('C:\', 'Please select the folder to save the analysis in');
            end
            if ~isequal(folder_name,0)
                app.SelectedOutputFolder.Value = folder_name;
                app.SelectedOutputFolder.Visible = 1;
                KIM.KIMOutputFolder=folder_name;
            end
        end

        % Selection changed function: AnalysistypeButtonGroup
        function AnalysistypeButtonGroupSelectionChanged(app, event)
            selectedButton = app.AnalysistypeButtonGroup.SelectedObject;
            if strcmpi(selectedButton.Text,'Static')
                app.StaticShiftsmmPanel.Visible = 1;
                app.MotionTracePanel.Visible = 0;
            else
                app.StaticShiftsmmPanel.Visible = 0;
                app.MotionTracePanel.Visible = 1;
            end
        end

        % Value changed function: LateralShift
        function LateralShiftValueChanged(app, event)
            global KIM
            value_LR = str2double(app.LateralShift.Value);
            KIM.value_LR = value_LR;
        end

        % Value changed function: LongShift
        function LongShiftValueChanged(app, event)
            global KIM
            value_SI = str2double(app.LongShift.Value);
            KIM.value_SI = value_SI;
        end

        % Value changed function: VertShift
        function VertShiftValueChanged(app, event)
            global KIM
            value_AP = str2double(app.VertShift.Value);
            KIM.value_AP = value_AP;
        end

        % Selection changed function: LinacVendorButtonGroup
        function LinacVendorButtonGroupSelectionChanged(app, event)
            global KIM
            selectedButton = app.LinacVendorButtonGroup.SelectedObject;
            if strcmpi(selectedButton.Text,'Varian')
                KIM.vendor = 'Varian';
            else
                KIM.vendor = 'Elekta';
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 666 653];
            app.UIFigure.Name = 'UI Figure';

            % Create AnalyseButton
            app.AnalyseButton = uibutton(app.UIFigure, 'push');
            app.AnalyseButton.ButtonPushedFcn = createCallbackFcn(app, @AnalyseButtonPushed2, true);
            app.AnalyseButton.FontSize = 26;
            app.AnalyseButton.FontWeight = 'bold';
            app.AnalyseButton.Position = [222 46 224 54];
            app.AnalyseButton.Text = 'Analyse';

            % Create AnalysistypeButtonGroup
            app.AnalysistypeButtonGroup = uibuttongroup(app.UIFigure);
            app.AnalysistypeButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @AnalysistypeButtonGroupSelectionChanged, true);
            app.AnalysistypeButtonGroup.Title = 'Analysis type';
            app.AnalysistypeButtonGroup.Position = [138 212 140 96];

            % Create DynamicButton
            app.DynamicButton = uiradiobutton(app.AnalysistypeButtonGroup);
            app.DynamicButton.Text = 'Dynamic';
            app.DynamicButton.Position = [8 27 68 22];
            app.DynamicButton.Value = true;

            % Create TreatmentInterruptButton
            app.TreatmentInterruptButton = uiradiobutton(app.AnalysistypeButtonGroup);
            app.TreatmentInterruptButton.Text = 'Treatment Interrupt';
            app.TreatmentInterruptButton.Position = [8 5 124 22];

            % Create StaticButton
            app.StaticButton = uiradiobutton(app.AnalysistypeButtonGroup);
            app.StaticButton.Text = 'Static';
            app.StaticButton.Position = [8 49 52 22];

            % Create LinacVendorButtonGroup
            app.LinacVendorButtonGroup = uibuttongroup(app.UIFigure);
            app.LinacVendorButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @LinacVendorButtonGroupSelectionChanged, true);
            app.LinacVendorButtonGroup.Title = 'Linac Vendor';
            app.LinacVendorButtonGroup.Position = [396 223 149 74];

            % Create VarianButton
            app.VarianButton = uiradiobutton(app.LinacVendorButtonGroup);
            app.VarianButton.Text = 'Varian';
            app.VarianButton.Position = [11 28 56 22];
            app.VarianButton.Value = true;

            % Create ElektaButton
            app.ElektaButton = uiradiobutton(app.LinacVendorButtonGroup);
            app.ElektaButton.Text = 'Elekta/Varian with ADI';
            app.ElektaButton.Position = [11 6 140 22];

            % Create StaticShiftsmmPanel
            app.StaticShiftsmmPanel = uipanel(app.UIFigure);
            app.StaticShiftsmmPanel.Title = 'Static Shifts (mm)';
            app.StaticShiftsmmPanel.Visible = 'off';
            app.StaticShiftsmmPanel.FontWeight = 'bold';
            app.StaticShiftsmmPanel.FontSize = 14;
            app.StaticShiftsmmPanel.Position = [43 310 582 72];

            % Create LateralLRLabel
            app.LateralLRLabel = uilabel(app.StaticShiftsmmPanel);
            app.LateralLRLabel.HorizontalAlignment = 'right';
            app.LateralLRLabel.Position = [8 13 72 22];
            app.LateralLRLabel.Text = 'Lateral (LR):';

            % Create LateralShift
            app.LateralShift = uieditfield(app.StaticShiftsmmPanel, 'text');
            app.LateralShift.ValueChangedFcn = createCallbackFcn(app, @LateralShiftValueChanged, true);
            app.LateralShift.Position = [83 13 77 22];

            % Create LongSILabel
            app.LongSILabel = uilabel(app.StaticShiftsmmPanel);
            app.LongSILabel.HorizontalAlignment = 'right';
            app.LongSILabel.Position = [222 13 58 22];
            app.LongSILabel.Text = 'Long (SI):';

            % Create LongShift
            app.LongShift = uieditfield(app.StaticShiftsmmPanel, 'text');
            app.LongShift.ValueChangedFcn = createCallbackFcn(app, @LongShiftValueChanged, true);
            app.LongShift.Position = [283 13 77 22];

            % Create VertAPLabel
            app.VertAPLabel = uilabel(app.StaticShiftsmmPanel);
            app.VertAPLabel.HorizontalAlignment = 'right';
            app.VertAPLabel.Position = [430 13 58 22];
            app.VertAPLabel.Text = 'Vert (AP):';

            % Create VertShift
            app.VertShift = uieditfield(app.StaticShiftsmmPanel, 'text');
            app.VertShift.ValueChangedFcn = createCallbackFcn(app, @VertShiftValueChanged, true);
            app.VertShift.Position = [491 13 77 22];

            % Create MotionTracePanel
            app.MotionTracePanel = uipanel(app.UIFigure);
            app.MotionTracePanel.Title = 'Motion Trace';
            app.MotionTracePanel.FontWeight = 'bold';
            app.MotionTracePanel.FontSize = 14;
            app.MotionTracePanel.Position = [43 467 582 88];

            % Create SelectFileButton
            app.SelectFileButton = uibutton(app.MotionTracePanel, 'push');
            app.SelectFileButton.ButtonPushedFcn = createCallbackFcn(app, @SelectFileButtonPushed, true);
            app.SelectFileButton.Position = [6 35 133 22];
            app.SelectFileButton.Text = 'Select File';

            % Create FormattTxTyTzrxryrzLabel
            app.FormattTxTyTzrxryrzLabel = uilabel(app.MotionTracePanel);
            app.FormattTxTyTzrxryrzLabel.FontWeight = 'bold';
            app.FormattTxTyTzrxryrzLabel.Position = [198 30 337 32];
            app.FormattTxTyTzrxryrzLabel.Text = {'Robot motion format: t Tx Ty Tz rx ry rz'; 'Hexamotion format: x y z; is assumed to operate @ 50 Hz'};

            % Create SelectedfileEditFieldLabel_5
            app.SelectedfileEditFieldLabel_5 = uilabel(app.MotionTracePanel);
            app.SelectedfileEditFieldLabel_5.HorizontalAlignment = 'right';
            app.SelectedfileEditFieldLabel_5.Position = [10 4 74 22];
            app.SelectedfileEditFieldLabel_5.Text = 'Selected file:';

            % Create SelectedMotionFile
            app.SelectedMotionFile = uieditfield(app.MotionTracePanel, 'text');
            app.SelectedMotionFile.Editable = 'off';
            app.SelectedMotionFile.Visible = 'off';
            app.SelectedMotionFile.Position = [83 4 488 22];

            % Create KIMlogPanel
            app.KIMlogPanel = uipanel(app.UIFigure);
            app.KIMlogPanel.Title = 'KIM log';
            app.KIMlogPanel.FontWeight = 'bold';
            app.KIMlogPanel.FontSize = 14;
            app.KIMlogPanel.Position = [43 554 582 83];

            % Create SelectFolderButton
            app.SelectFolderButton = uibutton(app.KIMlogPanel, 'push');
            app.SelectFolderButton.ButtonPushedFcn = createCallbackFcn(app, @SelectFolderButtonPushed, true);
            app.SelectFolderButton.FontColor = [0.149 0.149 0.149];
            app.SelectFolderButton.Position = [6 30 133 22];
            app.SelectFolderButton.Text = 'Select Folder';

            % Create ThisisfoldercontainingtheKIMgeneratedtrajectoryfilesLabel
            app.ThisisfoldercontainingtheKIMgeneratedtrajectoryfilesLabel = uilabel(app.KIMlogPanel);
            app.ThisisfoldercontainingtheKIMgeneratedtrajectoryfilesLabel.Position = [175 30 318 22];
            app.ThisisfoldercontainingtheKIMgeneratedtrajectoryfilesLabel.Text = 'This is folder containing the KIM generated trajectory file/s';

            % Create SelectedfolderLabel_3
            app.SelectedfolderLabel_3 = uilabel(app.KIMlogPanel);
            app.SelectedfolderLabel_3.HorizontalAlignment = 'right';
            app.SelectedfolderLabel_3.Position = [7 5 89 22];
            app.SelectedfolderLabel_3.Text = 'Selected folder:';

            % Create SelectedKimFolder
            app.SelectedKimFolder = uieditfield(app.KIMlogPanel, 'text');
            app.SelectedKimFolder.Editable = 'off';
            app.SelectedKimFolder.Visible = 'off';
            app.SelectedKimFolder.Position = [95 5 476 22];

            % Create CoordinateFilePanel
            app.CoordinateFilePanel = uipanel(app.UIFigure);
            app.CoordinateFilePanel.Title = 'Co-ordinate File';
            app.CoordinateFilePanel.FontWeight = 'bold';
            app.CoordinateFilePanel.FontSize = 14;
            app.CoordinateFilePanel.Position = [43 381 582 87];

            % Create SelectFileButton_2
            app.SelectFileButton_2 = uibutton(app.CoordinateFilePanel, 'push');
            app.SelectFileButton_2.ButtonPushedFcn = createCallbackFcn(app, @SelectFileButton_2Pushed, true);
            app.SelectFileButton_2.Position = [6 34 133 22];
            app.SelectFileButton_2.Text = 'Select File';

            % Create ThisisthecoordinatesofthemarkerswithrespecttotheisocentreLabel
            app.ThisisthecoordinatesofthemarkerswithrespecttotheisocentreLabel = uilabel(app.CoordinateFilePanel);
            app.ThisisthecoordinatesofthemarkerswithrespecttotheisocentreLabel.Position = [159 41 384 22];
            app.ThisisthecoordinatesofthemarkerswithrespecttotheisocentreLabel.Text = 'These are the coordinates of the markers with respect to the isocentre';

            % Create FormatxyzspecifiedinEclipseElektaconventionLabel
            app.FormatxyzspecifiedinEclipseElektaconventionLabel = uilabel(app.CoordinateFilePanel);
            app.FormatxyzspecifiedinEclipseElektaconventionLabel.FontWeight = 'bold';
            app.FormatxyzspecifiedinEclipseElektaconventionLabel.Position = [159 26 343 16];
            app.FormatxyzspecifiedinEclipseElektaconventionLabel.Text = 'Format: x y z; specified in Eclipse/Elekta convention';

            % Create SelectedfileEditFieldLabel_6
            app.SelectedfileEditFieldLabel_6 = uilabel(app.CoordinateFilePanel);
            app.SelectedfileEditFieldLabel_6.HorizontalAlignment = 'right';
            app.SelectedfileEditFieldLabel_6.Position = [6 5 74 22];
            app.SelectedfileEditFieldLabel_6.Text = 'Selected file:';

            % Create SelectedCoordFile
            app.SelectedCoordFile = uieditfield(app.CoordinateFilePanel, 'text');
            app.SelectedCoordFile.Editable = 'off';
            app.SelectedCoordFile.Visible = 'off';
            app.SelectedCoordFile.Position = [79 5 492 22];

            % Create OutputFolderPanel
            app.OutputFolderPanel = uipanel(app.UIFigure);
            app.OutputFolderPanel.Title = 'Output Folder';
            app.OutputFolderPanel.FontWeight = 'bold';
            app.OutputFolderPanel.FontSize = 14;
            app.OutputFolderPanel.Position = [43 120 582 85];

            % Create OutputfolderButton
            app.OutputfolderButton = uibutton(app.OutputFolderPanel, 'push');
            app.OutputfolderButton.ButtonPushedFcn = createCallbackFcn(app, @OutputfolderButtonPushed, true);
            app.OutputfolderButton.Position = [6 36 146 22];
            app.OutputfolderButton.Text = 'Select folder';

            % Create SelectedfolderLabel_4
            app.SelectedfolderLabel_4 = uilabel(app.OutputFolderPanel);
            app.SelectedfolderLabel_4.HorizontalAlignment = 'right';
            app.SelectedfolderLabel_4.Position = [8 8 88 22];
            app.SelectedfolderLabel_4.Text = 'Selected folder:';

            % Create SelectedOutputFolder
            app.SelectedOutputFolder = uieditfield(app.OutputFolderPanel, 'text');
            app.SelectedOutputFolder.Editable = 'off';
            app.SelectedOutputFolder.Visible = 'off';
            app.SelectedOutputFolder.Position = [99 8 469 22];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = AnalyseKIMQA_UI_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end