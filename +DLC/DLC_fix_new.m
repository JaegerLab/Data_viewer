function [newX, newY, newP]=DLC_fix_new(xdata, ydata, pdata, deltathresh, noutlfrthresh)

% Li Su - modify to fix a single channel.
% deltathresh: Max difference in location between 2 frames (unit = pixels)
% noutlfrthresh: % max number of outlier frames between two detected frames
%
% Aurelie - Jaeger Lab - 11/16/2023
% - 3/30/2024: minor improvements 
% - 1/21/2025: added video frame rate and resolution as input and lowered threshold for error detection
% - 3/28/2025: modified code to also work for ladder-like wheel movies
% - 7/14/2025: modified code to also work for reaching movies (below camera)
%
% Matlab R2024b

% mouse_name: 'AP020'
% dateYYYYMMDD: '20230512' or 'All'
% marker_name: 'body_midpoint', 'tail_base',..., or {'body_midpoint','tail_base'} or 'All'.
% expt_type: 'openfield','ladderwheel','reaching_below'
% res: resolution of the video in cm/pixel (Openfield: 0.034 cm/pixel)
% plot_yn: 'plot_y' for plots to be created and 'plot_n' to skip plotting.
% Plotting is strongly recommended as it is the only way to be sure that the outlier correction process worked correctly.
% mov_yn: 'mov_y' for movies to be created and 'mov_n' to skip creating movies. The movies will display the frames with the original and corrected marker positions.

% Note that currrently this code works best when there aren't too many consecutive outlier frames. 

% %% Parameters to edit
% pathb = 'Z:\Analyzed_Data\Aurelie\OpenField'; % striatum/thalamus server
% pathmov = 'Z:\Video\Aurelie\Udall_Reaching_Videos'; % striatum/thalamus server
% 
% %% Experiment type-specific parameters
% if(strcmp(expt_type,'openfield'))
%     fovpix = [1200 1200]; % FOV in pixels, [x y]
%     res = 0.034; % resolution of the video in cm/pixel
%     frate = 40; % video acquisition rate in Hz
%     deltathresh = 40; %40, previously 55. Max difference in location between 2 frames (unit = pixels)
%     noutlfrthresh = 25; %25 % max number of outlier frames between two detected frames
%     pathbmouse = fullfile(pathb,mouse_name);
%     pathmovmouse = fullfile(pathmov,mouse_name);
% end
% if(strcmp(expt_type,'openfield150'))
%     fovpix = [1200 1200]; % FOV in pixels, [x y]
%     res = 0.034; % resolution of the video in cm/pixel
%     frate = 150; % video acquisition rate in Hz
%     deltathresh = 40; %40, previously 55. Max difference in location between 2 frames (unit = pixels)
%     noutlfrthresh = 25; %25 % max number of outlier frames between two detected frames
%     pathbmouse = fullfile(pathb,mouse_name);
%     pathmovmouse = fullfile(pathmov,mouse_name);
% end
% if(strcmp(expt_type,'ladderwheel'))
%     fovpix = [1920 1200]; % FOV in pixels, [x y] 
%     res = 0.05; % resolution of the video in cm/pixel %%% to measure and update
%     frate = 100; % video acquisition rate in Hz
%     deltathresh = 150; %150. Max difference in location between 2 frames (unit = pixels)
%     noutlfrthresh = 5; %5 % max number of outlier frames between two detected frames
%     pathbmouse = fullfile(pathb,mouse_name);
%     pathmovmouse = fullfile(pathmov,mouse_name);
% end
% if(strcmp(expt_type,'reaching_below'))
%     fovpix = [620 576]; % FOV in pixels, [x y] (original video is 576x576 but rotate it to have the paw rest bar at the bottom of the frame)
%     res = 0.05; % resolution of the video in cm/pixel %%% to measure and update
%     frate = 100; % video acquisition rate in Hz
%     deltathresh = 150; %150. Max difference in location between 2 frames (unit = pixels)
%     noutlfrthresh = 5; %5 % max number of outlier frames between two detected frames
%     pathbmouse = fullfile(pathb,mouse_name,dateYYYYMMDD);
%     pathmovmouse = fullfile(pathmov,mouse_name,dateYYYYMMDD);
% end
% 
% %% General parameters
% %close all
% set(0,'DefaultFigureWindowStyle','docked')
% 
% %% Load data
% cd(pathbmouse)
% listdat = dir([ '*' '_markerPos.mat']); % flip_ :use videos with improved contrast and brightness (_mod)
% if(isempty(listdat))
%     error('No markerPos mat file')
% end
% if(~strcmp(dateYYYYMMDD,'All'))
%     idk = cellfun(@(x) ~isempty(x),strfind({listdat(:).name},dateYYYYMMDD));
%     listdat = listdat(idk);
%     clearvars idk
% end
% %% Identify errors in marker location using delta position across two consecutive frames (1D speed of movement)
% 
% bs1 = 5; % pixels
% bedge1 = {0:bs1:fovpix(1),0:bs1:fovpix(2)};
% 
% bs2 = 1; % frames
% 
% for d=1:length(listdat)
%     cd(pathbmouse)
%     markerposOri= struct2array(load(listdat(d).name));
%     if(~iscell(marker_name))
%         if(~strcmp(marker_name,'All'))
%             markerposTp.(marker_name) = markerposOri.(marker_name);
%         else
%             markerposTp = markerposOri;
%         end
%     else
%         for fi=1:length(marker_name)
%             markerposTp.(marker_name{fi}) = markerposOri.(marker_name{fi});
%         end
%     end
%     markernames = fieldnames(markerposTp);
%     xyp = fieldnames(markerposTp.(markernames{1}));
%     frames =1:length(markerposTp.(markernames{1}).(xyp{1}));
%     bedge2 = 0:bs2:length(markerposTp.(markernames{1}).(xyp{1}));
% 
%     for m=1:length(markernames)
%         disp(markernames{m})
%         datx = markerposTp.(markernames{m}).(xyp{1});
%         daty = markerposTp.(markernames{m}).(xyp{2});
%         datxy = {datx,daty};
%         datxyor = {datx,daty};
% 
%         if(sum(isnan(datx))~=0 || sum(isnan(daty))~=0)
%             idnansx = isnan(datx);
%             idnansy = isnan(daty);
%             datx = interp1(1:length(datx),datx,1:length(datx),'pchip');
%             daty = interp1(1:length(daty),daty,1:length(daty),'pchip');
%             disp('NaNs in DLC - x/y outputs, interpolate first')
%             datxy = {datx,daty};
%         end
% 
%         clearvars datx daty
% 
%         datprob = markerposTp.(markernames{m}).p;

        datxy = {xdata,ydata};
        if nargin ==3 
            datprob = pdata;
        else
            datprob = zeros(size(xdata));
        end
        frames =1:length(xdata);

        % calculate delta of position across consecutive frames
        deltaxy = cellfun(@(x) diff(x),datxy,'UniformOutput',0);
        for xy=1:length(deltaxy)
            temp = deltaxy{xy};
            temp(temp<0)=0;
            [~,peaks1{xy}] = findpeaks(temp,'MinPeakHeight',deltathresh);
            temp = deltaxy{xy};
            temp(temp>0)=0;
            temp = abs(temp);
            [~,peaks2{xy}] = findpeaks(temp,'MinPeakHeight',deltathresh);
            peaks{xy} = sort([peaks1{xy} peaks2{xy}]);
            clearvars temp peaks1 peaks2
        end
        idrm = cellfun(@(x) [frames(1) x frames(end)],peaks,'UniformOutput',0);
        deltaidrm = cellfun(@(x) diff(x),idrm,'UniformOutput',0); % number of frames between two frames with speed>deltathresh

        %identify frames with incorrect marker location
        %1 delta larger than deltathresh pixels
        rem1dtp = cell(size(datxy));
        for n=1:length(deltaidrm)
            if(~isempty(deltaidrm{n}))
                deltaidrmbg = deltaidrm{n}>=noutlfrthresh;
                if(sum(deltaidrmbg)~=0)
                    idrem1dtp = diff([deltaidrmbg(1) deltaidrmbg])==0 & deltaidrmbg==1;
                    idrem1dtp = idrem1dtp(2:end);
                    rem1dtp{n} = idrm{n}([false idrem1dtp false]);
                end
            end
        end
        idrm = cellfun(@(x) x(2:end-1),idrm,'UniformOutput',0);
        clearvars deltaidrm
        deltaidrm = cellfun(@(x) diff(x),idrm,'UniformOutput',0); % number of frames between two frames with speed>deltathresh

        for xy=1:size(deltaidrm,2)
            idk = deltaidrm{xy}>=noutlfrthresh;
            idkk = diff([true idk true]);
            idkkend = find(idkk==1);
            idkkst = find(idkk==-1);
            ev = find(mod(idkkend-idkkst,2)==0);
            if(~isempty(ev))
                temp = idrm{xy}(idkkend(ev));
                temp = temp+1;
                idrm{xy} = sort([idrm{xy} temp]);
                clearvars temp
            end
            clearvars ev idkkst idkkend idkk idk
        end

        for xy=1:size(rem1dtp,2)
            if(~isempty(rem1dtp{xy}))
                idk=~ismember(idrm{xy},rem1dtp{xy});
                idrm{xy}=idrm{xy}(idk);
                clearvars idk
            end
        end
        clearvars xy
        
        %remove outlier marker locations and interpolate actual location.
        %Make sure to remove in both x and y dimensions, even when outlier was only detected in one of the dimensions
        datxypost = datxy;
        xinterp = cellfun(@(x) 1:length(x),datxy,'UniformOutput',0);
        for xy=1:size(datxypost,2)
            if(~isempty(rem1dtp{xy}))
                datxypost{xy}(rem1dtp{xy})=nan;
                datprob(rem1dtp{xy})=1;
                if(xy==1)
                    datxypost{xy}(rem1dtp{2})=nan;
                end
                if(xy==2)
                    datxypost{xy}(rem1dtp{1})=nan;
                end
            end
            if(~isempty(idrm{xy}))
                for r=1:length(idrm{xy})/2
                    datxypost{xy}(idrm{xy}(2*r-1)+1:idrm{xy}(2*r))=nan;
                    datprob(idrm{xy}(2*r-1)+1:idrm{xy}(2*r))=1;
                end
                if(xy==1)
                    for r=1:length(idrm{2})/2
                        datxypost{xy}(idrm{2}(2*r-1)+1:idrm{2}(2*r))=nan;
                    end
                end
                if(xy==2)
                    for r=1:length(idrm{1})/2
                        datxypost{xy}(idrm{1}(2*r-1)+1:idrm{1}(2*r))=nan;
                    end
                end
            end
            if(sum(isnan(datxypost{xy}))~=0)
                datxypost{xy} = interp1(xinterp{xy},datxypost{xy},xinterp{xy},'pchip');
            end
            if(exist('idnansx','var') || exist('idnansy','var'))
                datxypost{1}(idnansx)=NaN;
                datxypost{2}(idnansy)=NaN;
                disp('X/Y exist')
            end      
        end
        clearvars idnansx idnansy

        %save
        newX = datxypost{1};
        newY = datxypost{2};
        newP = datprob;

        % markerpos = markerposOri;
        % save(listdat(d).name,'markerpos')
        % clearvars markerpos
% 
%         if(strcmp(plot_yn,'plot_y')) %plots for checking
% 
%             set(0,'DefaultFigureWindowStyle','docked')
%             colp = {'c','g','k'};
% 
%             % x,y as a function of delta over time (frame number)
%             fig1=figure;
%             for i=1:length(datxypost)
%                 sp(i)=subplot(length(datxypost)+1,1,i);
%                 plot(datxyor{i},'k')
%                 hold on
%                 plot(datxypost{i},'Color',colp{i})
%                 plot(frames(idrm{i}),datxypost{i}(idrm{i}),'*r')
%                 if(~isempty(rem1dtp{i}))
%                     plot(frames(rem1dtp{i}),datxypost{i}(rem1dtp{i}),'*m')
%                 end
%                 axis tight
%                 if(i==1)
%                     ylim([-100 fovpix(1)+100])
%                     ylabel('pixel')
%                 else
%                     ylim([-100 fovpix(2)+100])
%                     ylabel('pixel')
%                 end
%                 legend({'original','corrected'},'Location','eastoutside')
%                 title([xyp{i} ' position'])
%                 if(strcmp(expt_type,'ladderwheel'))
%                     xlim([5000 10000])
%                 end
%             end
%             sp(length(datxypost)+1)=subplot(length(datxypost)+1,1,length(datxypost)+1);
%             speed = sqrt(diff(datxy{1}).^2 + diff(datxy{2}).^2)*frate*res; % cm/s
%             speedpost = sqrt(diff(datxypost{1}).^2 + diff(datxypost{2}).^2)*frate*res; % cm/s
%             plot([speed NaN],'k')
%             hold on
%             plot([speedpost NaN],'Color',[255 178 102]/255)
%             axis tight
%             ylabel('cm/sec')
%             xlabel('frame #')
%             legend({'original','corrected'},'Location','eastoutside')
%             title('2D speed')
%             % if(strcmp(expt_type,'ladderwheel'))
%             %     xlim([5000 10000])
%             % end            
%             linkaxes(sp,'x')
%             sgtitle(['Outliers removal   (' markernames{m} ', ' mouse_name ', ' listdat(d).name(33:40) ', ' listdat(d).name(42:50) ')'],'Interpreter','none')
% 
%             %plot deltax and deltay distributions plus threshold
%             fig2=figure;
%             deltaxyhist = cellfun(@(x,y) histcounts(x,y),deltaxy,bedge1,'UniformOutput',0);
%             for i=1:length(datxypost)
%                 subplot(2,length(datxypost),i)
%                 bar(bedge1{i}(1:end-1)+bs1/2,deltaxyhist{i},1,'EdgeColor',colp{i},'FaceColor',colp{i})
%                 hold on
%                 plot([deltathresh deltathresh],[0 max(deltaxyhist{i})],'k--')
%                 xlabel('pixel')
%                 ylabel('counts')
%                 title(['\Delta' xyp{i}])
%                 subplot(2,length(datxypost),i+length(datxypost))
%                 bar(bedge1{i}(1:end-1)+bs1/2,deltaxyhist{i},1,'EdgeColor',colp{i},'FaceColor',colp{i})
%                 hold on
%                 plot([deltathresh deltathresh],[0 max(deltaxyhist{i})],'k--')
%                 xlabel('pixel')
%                 ylabel('counts (zoom 0-10)')
%                 ylim([0 10])
%             end
%             sgtitle(['Position diff across frames    (' markernames{m} ', ' mouse_name ', ' listdat(d).name(33:40) ', ' listdat(d).name(42:50) ')'],'Interpreter','none')
% 
%             % plot deltid200x and deltid200y and threshold on duration (nframes) between two outlier frames
%             fig3=figure;
%             deltaidrmhist = cellfun(@(x) histcounts(x,bedge2),deltaidrm,'UniformOutput',0);
%             for i=1:length(deltaidrmhist)
%                 subplot(1,length(deltaidrmhist),i)
%                 bar(bedge2(1:end-1)+bs2/2,deltaidrmhist{i},1,'EdgeColor',colp{i},'FaceColor',colp{i})
%                 hold on
%                 plot([noutlfrthresh noutlfrthresh],[0 max(deltaidrmhist{i})],'k--')
%                 xlim([0 50])
%                 xlabel('n frames')
%                 ylabel('counts')
%                 title('Duration between outliers frames')
%             end
%             sgtitle(['Incorrect position duration    (' markernames{m} ', ' mouse_name ', ' listdat(d).name(33:40) ', ' listdat(d).name(42:50) ')'],'Interpreter','none')
% 
%             % save figures
%             if(exist(fullfile(pathbmouse,'Figs'),'dir')~=7)
%                 mkdir('Figs')
%             end
%             cd('Figs')
% 
%             savefig(fig1,[mouse_name '_' listdat(d).name(33:50) '_x_y_corr_' markernames{m}])
%             print(fig1,[mouse_name '_' listdat(d).name(33:50) '_x_y_corr_' markernames{m}],'-dtiff')
% 
%             savefig(fig2,[mouse_name '_' listdat(d).name(33:50) '_x_y_deltas_' markernames{m}])
%             print(fig2,[mouse_name '_' listdat(d).name(33:50) '_x_y_deltas_' markernames{m}],'-dtiff')
% 
%             savefig(fig3,[mouse_name '_' listdat(d).name(33:50) '_x_y_deltasdur_' markernames{m}])
%             print(fig3,[mouse_name '_' listdat(d).name(33:50) '_x_y_deltasdur_' markernames{m}],'-dtiff')
%             cd ..
% 
%         end
% 
%         if(strcmp(mov_yn,'mov_y'))%create movie with frames where there is a difference between original marker position and updated marker position
%             frmv = rem1dtp;
%             for xy=1:size(frmv,2)
%                 tempo = [];
%                 for n=1:length(idrm{xy})/2
%                     tempo = [tempo idrm{xy}(2*n-1):idrm{xy}(2*n)];
%                 end
%                 frmv{xy}= sort([frmv{xy} tempo]);
%                 clearvars tempo
%             end
% 
%             cd(pathmovmouse)
%             set(0,'DefaultFigureWindowStyle','normal')
%             tempmov = VideoReader([listdat(d).name(1:end-14) '.mp4']);
%             vw = VideoWriter([mouse_name '_' listdat(d).name(36:43) '_' markernames{m} '_corr_outliers' '.avi']);
%             vw.FrameRate = 0.75;
%             open(vw);
%             fr=1;
%             while(hasFrame(tempmov) && fr<=length(datxy{1}))
%                 if(sum(frmv{1}==fr))
%                     frame = read(tempmov,fr); %h x w x 3 (RGB24 image)
%                     figtemp = figure;
%                     imagesc(frame)
%                     hold on
%                     plot(datxy{1}(fr),datxy{2}(fr),'oy','MarkerFaceColor','y','Markersize',1.5)
%                     hold on
%                     plot(datxypost{1}(fr),datxypost{2}(fr),'or','MarkerFaceColor','r','Markersize',1.5)
%                     axis square
%                     colormap gray
%                     sigtitle(['frame: ' num2str(fr)])
%                     ftemp=getframe(figtemp);
%                     writeVideo(vw,ftemp);
%                     close(figtemp)
%                 end
%                 fr = fr+1
%             end
%         end
%     end
% end
% 
% 
% 
% 
% end