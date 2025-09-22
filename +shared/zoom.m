function zoomLim = zoom(curLim, curTime, action)



switch lower(action)
    case 'in'
        if curTime < curLim(1) || curTime > curLim(2)
            curTime = mean(curLim);
        end
        zoomLim = (curTime + curLim)/2;
    case 'out'
        if curTime < curLim(1) || curTime > curLim(2)
            curTime = mean(curLim);
        end
        zoomLim = curLim + (curLim - curTime);
    case 'pan'
        if curTime <= curLim(1) || curTime >= curLim(2)
            winWidth = abs(diff(curLim))/2;
            zoomLim = curTime + [-winWidth, winWidth];
        else
            zoomLim = curLim;
        end
end
% set(handle, 'xLim', zoomLim);


