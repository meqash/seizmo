function [ncmp]=getncmp(data)
%GETNCMP    Return the number of dependent components for SEIZMO records
%
%    Usage:    ncmp=getncmp(data)
%
%    Description: GETNCMP(DATA) returns the number of dependent components
%     for each record in DATA.  This is basically a workaround for handling
%     filetypes that do not support multiple components (and thus not
%     having the NCMP field) at the same time as ones that do.
%
%    Notes:
%     - CHECKHEADER is not run
%
%    Examples:
%     Compare the number of components for a time series and spectral file:
%      getncmp([data(1) dft(data(1))])
%
%    See also: GETHEADER, GETENUMID, GETENUMDESC, GETLGC

%     Version History:
%        Oct.  7, 2008 - initial version
%        Nov. 16, 2008 - update for new name schema (now GETNCMP)
%        Apr. 23, 2009 - fix nargchk for octave, move usage up
%        June  3, 2009 - minor doc fix
%        Oct. 16, 2009 - drop warnings, allow 0 cmp records
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated Oct. 16, 2009 at 09:00 GMT

% todo:

% input check
msg=nargchk(1,1,nargin);
if(~isempty(msg)); error(msg); end

% get ncmp via GH, avoiding warnings
ncmp=getheader(data,'ncmp');

% clean up and check ncmp
ncmp(isnan(ncmp))=1;
if(any(ncmp<0 | fix(ncmp)~=ncmp))
    error('seizmo:getncmp:badNumCmp',...
        'Field NCMP must be integer >=0!')
end

end
