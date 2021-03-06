function dynare(fname, varargin)
%       This command runs dynare with specified model file in argument
%       Filename.
%       The name of model file begins with an alphabetic character,
%       and has a filename extension of .mod or .dyn.
%       When extension is omitted, a model file with .mod extension
%       is processed.
%
% INPUTS
%   fname:      file name
%   varargin:   list of arguments following fname
%
% OUTPUTS
%   none
%
% SPECIAL REQUIREMENTS
%   none

% Copyright (C) 2001-2018 Dynare Team
%
% This file is part of Dynare.
%
% Dynare is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% Dynare is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with Dynare.  If not, see <http://www.gnu.org/licenses/>.

if ~nargin || strcmpi(fname,'help')
    skipline()
    disp(['This is dynare version ' dynare_version() '.'])
    skipline()
    disp('USAGE: dynare FILENAME[.mod,.dyn] [OPTIONS]')
    skipline()
    disp('dynare executes instruction included in FILENAME.mod.')
    disp('See the reference manual for the available options.')
    skipline()
    return
end

% Set default local options
change_path_flag = true;

% Filter out some options.
preprocessoroutput = true;
if nargin>1
    id = strfind(varargin,'nopathchange');
    if ~all(cellfun(@isempty, id))
        change_path_flag = false;
        varargin(cellfun(@isempty, id) == 0) = [];
    end
    id = strfind(varargin, 'nopreprocessoroutput');
    if ~all(cellfun(@isempty, id))
        preprocessoroutput = false;
    end
end

% Check matlab path
check_matlab_path(change_path_flag);

% Detect if MEX files are present; if not, use alternative M-files
dynareroot = dynare_config('', preprocessoroutput);

warning_config()

if ~isoctave
    if matlab_ver_less_than('7.5')
        warning('This version of Dynare has only been tested on MATLAB 7.5 (R2007b) and above. Since your MATLAB version is older than that, Dynare may fail to run, or give unexpected results. Consider upgrading your MATLAB installation, or switch to Octave.');
    end
end

% disable output paging (it is on by default on Octave)
more off

% sets default format for save() command
if isoctave
    if octave_ver_less_than('3.8')
        default_save_options('-mat')
    else
        save_default_options('-mat')
    end
end

if nargin < 1
    error('DYNARE: you must provide the name of the MOD file in argument')
end

if ~ischar(fname)
    error('DYNARE: argument of dynare must be a text string')
end

% Testing if filename has more than one period (not allowed).
dot_location=strfind(fname,'.');
if length(dot_location)>1
    error('DYNARE: Periods in filenames are only allowed for .mod or .dyn extensions')
end

if dot_location==length(fname)
    error('DYNARE: Periods in filenames are only allowed for .mod or .dyn extensions')
end

% Add dyn or mod extension to the file name if not already provided.
if isempty(dot_location)
    fnamelength = length(fname);
    fname1 = [fname '.dyn'];
    d = dir(fname1);
    if length(d) == 0
        fname1 = [fname '.mod'];
    end
    fname = fname1;
else
    % Check provided file extension.
    if ~strcmpi(fname(dot_location+1:end), 'mod') && ~strcmpi(fname(dot_location+1:end), 'dyn')
        error('DYNARE: argument must be a filename with .mod or .dyn extensions')
    end
    fnamelength = length(fname) - 4;
end

if fnamelength + length('_set_auxiliary_variables') > namelengthmax()
    error('The name of your MOD file is too long, please shorten it')
end

% Workaround for a strange bug with Octave: if there is any call to exist(fname)
% before the call to the preprocessor, then Octave will use the old copy of
% the .m instead of the newly generated one. Deleting the .m beforehand
% fixes the problem.
if isoctave && length(dir([fname(1:(end-4)) '.m'])) > 0
    delete([fname(1:(end-4)) '.m'])
end

if ~isempty(strfind(fname,filesep))
    fprintf('\nIt seems you are trying to call a mod-file not located in the "Current Folder". This is not possible (the %s symbol is not allowed in the name of the mod file).\n', filesep)
    [pathtomodfile,basename,ext] = fileparts(fname);
    if exist(pathtomodfile,'dir')
        filesindirectory = dir(pathtomodfile);
        filesindirectory = struct2cell(filesindirectory);
        filesindirectory = filesindirectory(1,:);
        if ~isempty(strmatch([basename '.mod'],filesindirectory)) || ~isempty(strmatch([basename '.dyn'],filesindirectory))
            fprintf('Please set your "Current Folder" to the folder where the mod-file is located using the following command:\n')
            fprintf('\n  >> cd %s\n\n',pathtomodfile)
        else
            fprintf('The file %s[.mod,.dyn] could not be located!\n\n',basename)
        end
    end
    error(['dynare:: can''t open ' fname, '.'])
end

if ~exist(fname,'file') || isequal(fname,'dir')
    fprintf('\nThe file %s could not be located in the "Current Folder". Check whether you typed in the correct filename\n',fname)
    fprintf('and whether the file is really located in the "Current Folder".\n')
    try
        list_of_mod_files = ls('*.mod');
        fprintf('\nCurrent folder is %s, and contains the following mod files:\n\n',pwd)
        disp(list_of_mod_files)
    catch
        fprintf('\nCurrent folder is %s, and does not contain any mod files.\n\n',pwd)
    end
    error(['dynare:: can''t open ' fname])
end

if ~isvarname(fname(1:end-4))
    error('DYNARE: argument of dynare must conform to Matlab''s convention for naming functions, i.e. start with a letter and not contain special characters. Please rename your MOD-file.')
end

% pre-dynare-preprocessor-hook
if exist(fname(1:end-4),'dir') && exist([fname(1:end-4) filesep 'hooks'],'dir') && exist([fname(1:end-4) filesep 'hooks/priorprocessing.m'],'file')
    run([fname(1:end-4) filesep 'hooks/priorprocessing'])
end

if ispc
    arch = getenv('PROCESSOR_ARCHITECTURE');
else
    [junk, arch] = system('uname -m');
end

if isempty(strfind(arch, '64'))
    arch_ext = '32';
    if preprocessoroutput
        disp('Using 32-bit preprocessor');
    end
else
    arch_ext = '64';
    if preprocessoroutput
        disp('Using 64-bit preprocessor');
    end
end

% Read options from the first line in mod/dyn file.
fid = fopen(fname, 'r');
firstline = fgetl(fid);
fclose(fid);
if regexp(firstline, '\s*\/\/', 'once') == 1
    firstline = regexprep(firstline, '\s*\/\/', '');
    if ~isempty(regexp(firstline, '(^\s*\-\-\+\s*options:\s*)', 'once')) ...
        && ~isempty(regexp(firstline, '(\s*\+\-\-.*$)', 'once'))
        firstline = regexprep(firstline, '(^\s*\-\-\+\s*options:\s*)', '');
        firstline = regexprep(firstline, '(\s*\+\-\-.*$)', '');
        dynoption = strsplit(firstline, {' ', ','});
        if isequal(nargin, 1)
            varargin = dynoption;
        else
            varargin = union(varargin, dynoption);
        end
    end
end

command = ['"' dynareroot 'preprocessor' arch_ext filesep 'dynare_m" ' fname] ;
for i=1:length(varargin)
    command = [command ' ' varargin{i}];
end

if preprocessoroutput
    fprintf(['Starting Dynare (version ' dynare_version() ').\n']);
    fprintf('Calling Dynare with arguments: ');
    disp(varargin);
    if isempty(varargin)
        disp('none')
    end
end

[status, result] = system(command);
if status ~= 0 || preprocessoroutput
    disp(result)
end
if ismember('onlymacro', varargin)
    if preprocessoroutput
        disp('Preprocesser stopped after macroprocessing step because of ''onlymacro'' option.');
    end
    return
end

if ismember('onlyjson', varargin)
    if preprocessoroutput
        disp('Preprocesser stopped after preprocessing step because of ''onlyjson'' option.');
    end
    return;
end

% post-dynare-prerocessor-hook
if exist(fname(1:end-4),'dir') && exist([fname(1:end-4) filesep 'hooks'],'dir') && exist([fname(1:end-4) filesep 'hooks/postprocessing.m'],'file')
    run([fname(1:end-4) filesep 'hooks/postprocessing'])
end

% Save preprocessor result in logfile (if `no_log' option not present)
no_log = 0;
for i=1:length(varargin)
    no_log = no_log || strcmp(varargin{i}, 'nolog');
end
if ~no_log
    logname = [fname(1:end-4) '.log'];
    fid = fopen(logname, 'w');
    fprintf(fid, '%s', result);
    fclose(fid);
end

if status
    % Should not use "error(result)" since message will be truncated if too long
    error('DYNARE: preprocessing failed')
end

if ~ isempty(find(abs(fname) == 46))
    fname = fname(:,1:find(abs(fname) == 46)-1) ;
end
evalin('base',fname) ;
