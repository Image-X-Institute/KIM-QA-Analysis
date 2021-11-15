classdef ManualMatch_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        AutoMatchButton            matlab.ui.control.Button
        FinishedButton             matlab.ui.control.Button
        FineSlider                 matlab.ui.control.Slider
        FineSliderLabel            matlab.ui.control.Label
        GrossSlider                matlab.ui.control.Slider
        GrossSliderLabel           matlab.ui.control.Label
        DisplayOptionsButtonGroup  matlab.ui.container.ButtonGroup
        LRButton                   matlab.ui.control.RadioButton
        APButton                   matlab.ui.control.RadioButton
        SIButton                   matlab.ui.control.RadioButton
        MagnitudeButton            matlab.ui.control.RadioButton
        UIDiff                     matlab.ui.control.UIAxes
        UIAxes                     matlab.ui.control.UIAxes
    end


    properties (Access = public)
        Done % Trigger for when app closes to pass details back to calling m file
        data % repository for data passed into the app
    end

    properties (Access = private)
    end

    methods (Access = private)

        function UpdatePlots(app, RawSource, RawCompare)
            app.data.Source = smoothdata(RawSource,'gaussian',1/mean(diff(app.data.Motion.timestamps))); % Smooth the source motion using a 1 second window
            app.data.Source = app.data.Source-min(app.data.Source);

            app.data.Compare = smoothdata(RawCompare,'gaussian',5);  % smooth the KIM data using a 5 data point window
            app.data.Compare = app.data.Compare-min(app.data.Compare);

            UpdatePlotDisplay(app)
        end

        function UpdatePlotDisplay(app)
            CompareTime = app.data.KIM.time.raw + app.GrossSlider.Value + app.FineSlider.Value;
%             StartIndex = find(CompareTime >= 0, 1, 'first');
%             EndIndex = find(CompareTime < app.data.Motion.timestamps(end), 1, 'last');
            
%             plot(app.UIAxes, app.data.Motion.timestamps, app.data.Source, 'k-', CompareTime(StartIndex:EndIndex), app.data.Compare(StartIndex:EndIndex), 'g.')
            plot(app.UIAxes, app.data.Motion.timestamps, app.data.Source, 'k-', CompareTime, app.data.Compare, 'g.')
            app.UIAxes.XLim = [0 ceil(app.data.Motion.timestamps(end)/10)*10];

            InterpSource = interp1(app.data.Motion.timestamps, app.data.Source, CompareTime,'linear',-100);

            plot(app.UIDiff, app.data.KIM.time.raw, app.data.Compare-InterpSource)
            app.UIDiff.XLim = [0 ceil(app.data.KIM.time.raw(end)/10)*10];
            app.UIDiff.YLim = [-5 5];
        end
    end

    methods (Access = public)

        function CloseThisWindow(app)
            delete(app)
        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, dataKIM, dataMotion)
            app.Done = 0;

            app.data.KIM = dataKIM;
            app.data.Motion = dataMotion;
%             EndIndex = find(app.data.KIM.time.raw < app.data.Motion.timestamps(end), 1, 'last');

            RawSource = sqrt(sum(app.data.Motion.raw.^2,2));
            RawCompare = sqrt(sum(app.data.KIM.coord.shifted.^2,2));

            SliderMax = ceil(app.data.Motion.timestamps(end)/10)*10;
            SliderMin = ceil(app.data.KIM.time.raw(end)/10)*10;
            app.GrossSlider.Limits = [-SliderMin SliderMax];
            app.GrossSlider.MajorTicks = app.GrossSlider.Limits(1):50:app.GrossSlider.Limits(2);
            app.GrossSlider.MinorTicks = app.GrossSlider.Limits(1):5:app.GrossSlider.Limits(2);
            app.GrossSlider.Value = 0;

            app.FineSlider.Limits = [-5 5];
            app.FineSlider.MajorTicks = app.FineSlider.Limits(1):1:app.FineSlider.Limits(2);
            app.FineSlider.MinorTicks = app.FineSlider.Limits(1):0.25:app.FineSlider.Limits(2);
            app.FineSlider.Value = 0;

            UpdatePlots(app, RawSource, RawCompare);
        end

        % Selection changed function: DisplayOptionsButtonGroup
        function DisplayOptionsButtonGroupSelectionChanged(app, event)
            if app.MagnitudeButton.Value
                RawSource = sqrt(sum(app.data.Motion.raw.^2,2));
                RawCompare = sqrt(sum(app.data.KIM.coord.shifted.^2,2));
            elseif app.SIButton.Value
                RawSource = app.data.Motion.raw(:,2);
                RawCompare = app.data.KIM.coord.shifted(:,2);
            elseif app.APButton.Value
                RawSource = app.data.Motion.raw(:,3);
                RawCompare = app.data.KIM.coord.shifted(:,3);
            elseif app.LRButton.Value
                RawSource = app.data.Motion.raw(:,1);
                RawCompare = app.data.KIM.coord.shifted(:,1);
            end
            UpdatePlots(app, RawSource, RawCompare);
        end

        % Value changed function: GrossSlider
        function GrossSliderValueChanged(app, event)
            app.FineSlider.Value = 0;
            UpdatePlotDisplay(app);
        end

        % Value changed function: FineSlider
        function FineSliderValueChanged(app, event)
            UpdatePlotDisplay(app);
        end

        % Button pushed function: FinishedButton
        function FinishedButtonPushed(app, event)
            app.Done = 1;
        end

        % Button pushed function: AutoMatchButton
        function AutoMatchButtonPushed(app, event)
            TimeStep = mean(diff(app.data.Motion.timestamps))/4;
            ShiftValues = app.GrossSlider.Limits(1):TimeStep:app.GrossSlider.Limits(2);

            rmseSI = nan(1,length(ShiftValues));
            for a = 1:length(ShiftValues)
                mod_time = app.data.KIM.time.raw + ShiftValues(a);
                interpSource = interp1(app.data.Motion.timestamps, app.data.Source, mod_time,'linear',0);
                rmseSI(a) = sum((app.data.Compare-interpSource).^2)/size(app.data.Compare,1);
                if rem(a,1000)==0
                    app.GrossSlider.Value = ShiftValues(a);
                    GrossSliderValueChanged(app, event);
                    pause(0.05)
                end
            end
            [~,I] = min(rmseSI);
            app.GrossSlider.Value = ShiftValues(I);
            GrossSliderValueChanged(app, event);
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            delete(app)
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 640 480];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'KIM vs Motion')
            xlabel(app.UIAxes, 'Time')
            ylabel(app.UIAxes, 'Amplitude')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Position = [171 220 457 252];

            % Create UIDiff
            app.UIDiff = uiaxes(app.UIFigure);
            title(app.UIDiff, 'Diff')
            xlabel(app.UIDiff, 'Time')
            ylabel(app.UIDiff, 'Diff')
            zlabel(app.UIDiff, 'Z')
            app.UIDiff.Position = [171 17 457 104];

            % Create DisplayOptionsButtonGroup
            app.DisplayOptionsButtonGroup = uibuttongroup(app.UIFigure);
            app.DisplayOptionsButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @DisplayOptionsButtonGroupSelectionChanged, true);
            app.DisplayOptionsButtonGroup.Title = 'Display Options';
            app.DisplayOptionsButtonGroup.Position = [40 340 100 115];

            % Create MagnitudeButton
            app.MagnitudeButton = uiradiobutton(app.DisplayOptionsButtonGroup);
            app.MagnitudeButton.Text = 'Magnitude';
            app.MagnitudeButton.Position = [11 69 78 22];
            app.MagnitudeButton.Value = true;

            % Create SIButton
            app.SIButton = uiradiobutton(app.DisplayOptionsButtonGroup);
            app.SIButton.Text = 'SI (Y)';
            app.SIButton.Position = [11 48 65 22];

            % Create APButton
            app.APButton = uiradiobutton(app.DisplayOptionsButtonGroup);
            app.APButton.Text = 'AP (Z)';
            app.APButton.Position = [11 26 65 22];

            % Create LRButton
            app.LRButton = uiradiobutton(app.DisplayOptionsButtonGroup);
            app.LRButton.Text = 'LR (X)';
            app.LRButton.Position = [11 5 65 22];

            % Create GrossSliderLabel
            app.GrossSliderLabel = uilabel(app.UIFigure);
            app.GrossSliderLabel.HorizontalAlignment = 'right';
            app.GrossSliderLabel.Position = [169 199 38 22];
            app.GrossSliderLabel.Text = 'Gross';

            % Create GrossSlider
            app.GrossSlider = uislider(app.UIFigure);
            app.GrossSlider.ValueChangedFcn = createCallbackFcn(app, @GrossSliderValueChanged, true);
            app.GrossSlider.Position = [228 208 389 3];

            % Create FineSliderLabel
            app.FineSliderLabel = uilabel(app.UIFigure);
            app.FineSliderLabel.HorizontalAlignment = 'right';
            app.FineSliderLabel.Position = [185 157 29 22];
            app.FineSliderLabel.Text = 'Fine';

            % Create FineSlider
            app.FineSlider = uislider(app.UIFigure);
            app.FineSlider.Limits = [0 10];
            app.FineSlider.ValueChangedFcn = createCallbackFcn(app, @FineSliderValueChanged, true);
            app.FineSlider.Position = [228 166 389 3];

            % Create FinishedButton
            app.FinishedButton = uibutton(app.UIFigure, 'push');
            app.FinishedButton.ButtonPushedFcn = createCallbackFcn(app, @FinishedButtonPushed, true);
            app.FinishedButton.FontSize = 20;
            app.FinishedButton.FontWeight = 'bold';
            app.FinishedButton.Position = [40 48 100 173];
            app.FinishedButton.Text = 'Finished';

            % Create AutoMatchButton
            app.AutoMatchButton = uibutton(app.UIFigure, 'push');
            app.AutoMatchButton.ButtonPushedFcn = createCallbackFcn(app, @AutoMatchButtonPushed, true);
            app.AutoMatchButton.FontWeight = 'bold';
            app.AutoMatchButton.Position = [40 281 100 22];
            app.AutoMatchButton.Text = 'Auto Match';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ManualMatch_exported(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

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