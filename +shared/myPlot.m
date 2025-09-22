function hd = myPlot(plotFun, hd, field, ax, xdata, ydata, varargin)
% hd = myPlot(plotFun, hd, field, ax, xdata, ydata, linespec)
%
% check if the handle is saved in the field or not.
% if exists, update the x and y data in the existing plot.
% if not, create a new plot and save the handle.
%
% plotFun: plot function (eg: @plot, @yline, @scatter)
% hd:      structure to store handles
% field:   a string, fieldname under the structure
% ax:      the axis to plot in
% x/ydata: data arrays. If use @yline, put [] as xdata.
% varargin: additional arguments passed to plot function.

if nargin < 7
    varargin = {};
end

if isequal(plotFun, @xline)
    if ~isfield(hd, field) || ~ishghandle(hd.(field))
        hd.(field) = plotFun(ax, xdata, varargin{:});
    else
        set(hd.(field), "Value", xdata);
    end
elseif isequal(plotFun, @yline)
    if ~isfield(hd, field) || ~ishghandle(hd.(field))
        hd.(field) = plotFun(ax, ydata, varargin{:});
    else
        set(hd.(field), "Value", ydata);
    end
else
    if ~isfield(hd, field) || ~ishghandle(hd.(field))
        hd.(field) = plotFun(ax, xdata, ydata, varargin{:});
    else
        set(hd.(field), "XData", xdata, "YData", ydata);
    end
end
