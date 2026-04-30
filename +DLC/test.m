filename = 'Z:\Analyzed_Data\Mei\DLC\OpenField\LS331\20250607\Basler_acA1920-155umMED__40118562__20250607_103316279DLC_resnet50_OpenfieldJul25shuffle1_500000.csv';
dlc=DLC.read_dlc(filename);
x = dlc.L_forepaw_x;
y = dlc.L_forepaw_y;
p = dlc.L_forepaw_likelihood;
params = struct('jump_thres', 25, 'win_width', 30);
[x1, y1, p1, flags]= DLC.DLC_fix_new(x,y,p, params);

%%
figure;
idx = (1:length(x))'/150;
hold on
plot(idx, [x,y]);
plot(idx(flags==2),[x(flags==2), y(flags==2)],'rx');
plot(idx(flags==3),[x(flags==3), y(flags==3)],'g*', 'MarkerSize',12);

[x2, y2]= DLC.dlc_fix(x,y, p, 20, 30);
%%
h1=plot(idx,x1,'g');
h2=plot(idx,y1,'g');
uistack(h1,'bottom');
uistack(h2,'bottom');

h1=plot(idx,x2,'m');
h2=plot(idx,y2,'m');
uistack(h1,'bottom');
uistack(h2,'bottom');