function degenTest_analyzeSimData(pname)
% degenTest_analyzeSimData(pname)
%
% Controls MASH-FRET's interface to analyze synthetic state sequences from ASCII files stored in subfolders of `pname`
% optimized HMM parameters are exported in folder `pname`
% /!\ MASH-FRET must be open and the corresponding figure must be the last one selected!
% /!\ All transition analysis parameters, including import settings, must be set prior running the script
% /!\ Data sets are identified by the subfolder name
%
% example:
% degenTest_analyzeSimData('C:\Users\mimi\Documents\MyDataFolder\degenerated_test\testdata');

% default
deblurr = true; % remove blurr states and rewrite in files
if deblurr
    nHead = 2; % number of header line in files
    col = 8; % file column where FRET state sequences a written
    nCols = 9; % number of columns in file
end
V = 2; % number of states values
nRep = 5; % number of GMM iniializations
Dmax = 4; % max. number of degenerated states

if pname(end)~=filesep
    pname = [pname,filesep];
end

% get handle to MASH-FRET's figure
h_fig = gcf;
h = guidata(h_fig);
prev_mute = h.mute_actions;
h.mute_actions = true;
guidata(h_fig,h);

% get all subfolders
dlist = dir(pname);
D = size(dlist,1);
excl = false(1,D);
for d = 1:D
    if ~dlist(d,1).isdir || strcmp(dlist(d,1).name,'.') || ...
            strcmp(dlist(d,1).name,'..')
        excl(d) = true;
    end
end
dlist(excl,:) = [];

% deblurr sequences and re-write file
D = size(dlist,1);
nb = 0;
totIter = D*250;
titer = [];
td = 40;
if deblurr
    for d = 1:D
        tid = tic;
        
        % import ASCII files in TP
        pname_in = [pname,dlist(d,1).name,filesep,'traces_ASCII',filesep];
        flist = dir([pname_in,'*.txt']);
        F = size(flist,1);
        fnames = cell(1,F);
        for f = 1:F
            fnames{f} = flist(f,1).name;

            % read data
            fid = fopen([pname_in,fnames{f}],'r');
            headers = cell(1,nHead);
            for head = 1:nHead
                headers{head} = fgetl(fid);
            end
            dat = [];
            while ~feof(fid)
                dat = cat(1,dat,str2num(fgetl(fid)));
            end
            fclose(fid);
            
            % deblurr data
%             dat(:,col) = deblurrSeq(dat(:,col));
            dat(dat(:,col)==-1,:) = [];
            
            % save to file
            fid = fopen([pname_in,fnames{f}],'Wt');
            for head = 1:nHead
                fprintf(fid,[headers{head},'\n']);
            end
            fprintf(fid,['%d',repmat('\t%d',[1,nCols-1]),'\n'],dat');
            fclose(fid);

            tleft = (totIter-(d-1)*250-f)*td/250;
            hrs = fix(tleft/3600);
            mns = fix((tleft-hrs*3600)/60);
            sec = round(tleft-hrs*3600-mns*60);
            nb = dispProgress(...
                sprintf('Deblurr data: %i:%i:%i left...',hrs,mns,sec),nb);
        end
        
        titer = cat(2,titer,toc(tid));
        td = mean(titer);
    end
end

% analyze data
for d = 1:D
    % set root folder
    pushbutton_rootFolder_Callback({[pname,dlist(d,1).name]},[],h_fig);

    % import files in TA and select FRET data
    fprintf('Import files ...\n');
    pushbutton_TDPaddProj_Callback({pname_in,fnames},[],h_fig);
    h.popupmenu_TDPdataType.Value = 3;
    popupmenu_TDPdataType_Callback(h.popupmenu_TDPdataType,[],h_fig);

    % set TDP plot
    h.checkbox_TDP_statics.Value = 0;
    checkbox_TDP_statics_Callback(h.checkbox_TDP_statics,[],h_fig);

    % train GMM
    fprintf('train GMM ...\n');
    h.edit_TDPmaxiter.String = num2str(nRep);
    edit_TDPmaxiter_Callback(h.edit_TDPmaxiter,[],h_fig);
    h.edit_TDPnStates.String = num2str(V);
    edit_TDPnStates_Callback(h.edit_TDPnStates,[],h_fig);
    pushbutton_TDPupdateClust_Callback(h.pushbutton_TDPupdateClust,[],...
        h_fig)

    % optimize model
    fprintf('train HMM ...\n');
    h.edit_TA_mdlRestartNb.String = num2str(nRep);
    edit_TA_mdlRestartNb_Callback(h.edit_TA_mdlRestartNb,[],h_fig);
    h.edit_TA_mdlJmax.String = num2str(Dmax);
    edit_TA_mdlJmax_Callback(h.edit_TA_mdlJmax,[],h_fig);
    pushbutton_TA_refreshModel_Callback(h.pushbutton_TA_refreshModel,[],...
        h_fig)

    % export results
    fprintf('export results ...\n');
    h = guidata(h_fig);
    p = h.param.TDP;
    proj = p.curr_proj;
    tpe = p.curr_type(proj);
    tag = p.curr_tag(proj);
    trans_rates = p.proj{proj}.prm{tag,tpe}.mdl_res{1};
    trans_rates_err = p.proj{proj}.prm{tag,tpe}.mdl_res{2};
    ini_prob = p.proj{proj}.prm{tag,tpe}.mdl_res{3};
    simdat = p.proj{proj}.prm{tag,tpe}.mdl_res{4};
    FRET = p.proj{proj}.prm{tag,tpe}.mdl_res{5};
    BIC = p.proj{proj}.prm{tag,tpe}.mdl_res{6};
    save([pname,dlist(d,1).name,filesep,dlist(d,1).name,'_res.mat'],...
        'trans_rates','trans_rates_err','ini_prob','simdat','FRET','BIC',...
        '-mat');

    % save and close project
    fprintf('save project ...\n');
    pushbutton_TDPsaveProj_Callback(...
        {[pname,dlist(d,1).name],[dlist(d,1).name,'.mash']},[],h_fig);
    pushbutton_TDPremProj_Callback(h.pushbutton_TDPremProj,[],h_fig);
end

h = guidata(h_fig);
h.mute_actions = prev_mute;
guidata(h_fig,h);

disp('Routine completed!');