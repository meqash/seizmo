function [data]=interpolate(data,sr,method,new_b,new_e,extrap)
%INTERPOLATE    Interpolate SEIZMO records to a new samplerate
%
%    Usage:    data=interpolate(data,rate)
%              data=interpolate(data,rate,method)
%              data=interpolate(data,rate,method,new_b,new_e)
%              data=interpolate(data,rate,method,new_b,new_e,extrap)
%
%    Description: INTERPOLATE(DATA,RATE) interpolates SEIZMO records in
%     DATA to a new sample rate RATE.  As this is interpolation (the
%     default method is spline), edge effects are not an issue as they are
%     for SYNCRATES, SQUISH, and STRETCH but aliasing of high frequency
%     energy to lower frequencies is an issue when interpolating to a lower
%     sample rate.  Therefore, it is not recommended to downsample records
%     with INTERPOLATE (use SYNCRATES or squish).  RATE can be a vector of
%     rates with one element per record in DATA to interpolate records to
%     different rates.
%
%     INTERPOLATE(DATA,RATE,METHOD) allows selection of the interpolation
%     method from one of the following: 'nearest' (Nearest Neighbor),
%     'linear', 'spline' (Cubic Spline), or 'pchip' (Piecewise Cubic
%     Hermite).  Default is 'spline'.  Method can also be a list of methods
%     to specify a different interpolation method for each record.
%
%     INTERPOLATE(DATA,RATE,METHOD,TIME_START,TIME_END) specifies the time
%     window for interpolation.  The window can be a vector list to specify
%     a separate window for each record.
%
%     INTERPOLATE(DATA,RATE,METHOD,NEW_B,NEW_E,EXTRAP) sets the values
%     outside the time range of the input records to EXTRAP.  EXTRAP should
%     be a scalar of a vector of numbers to specify a different value for
%     each record.  EXTRAP may also be 'extrap', which will use the
%     interpolation method to extrapolate values outside the range.  The
%     default for EXTRAP is 'extrap'.
%
%    Notes:
%
%    Header changes: DELTA, NPTS, LEVEN, B, E, DEPMEN, DEPMIN, DEPMAX
%
%    Examples:
%     interpolate records at 5 sps
%      data=interpolate(data,5);  
%
%     interpolate records at 1 sps from 300 seconds to e
%      data=interpolate(data,1,[],300)
%
%     interpolate at 5 sps from 900 to 950 seconds using linear interp
%      data_pdiff=interpolate(data,5,'linear',900,950)
%
%     the same but setting any values outside the original time range to 0:
%      data_pdiff=interpolate(data,5,'linear',900,950,0);
%
%    See also: SYNCRATES, SQUISH, STRETCH, IIRFILTER

%     Version History:
%        Oct. 31, 2007 - initial version
%        Feb. 16, 2008 - doc update, code cleaning
%        Feb. 29, 2008 - better checks
%        Mar.  4, 2008 - better checks, class support
%        Mar. 20, 2008 - change input order
%        May  12, 2008 - fix dep* formula
%        June 15, 2008 - doc update, name changed from INTRPOL8 to
%                        INTERPOLATE
%        Nov. 22, 2008 - better checks, .dep & .ind rather than .x & .t,
%                        doc update, history fix, one CHANGEHEADER call,
%                        extrapolation
%        Apr. 23, 2009 - fix nargchk and seizmocheck for octave,
%                        move usage up
%        Sep. 11, 2009 - minor doc update
%        Jan. 30, 2010 - proper SEIZMO handling, seizmoverbose support
%        Feb.  3, 2010 - versioninfo caching
%        Mar.  4, 2010 - keep things consistent in case the e field is off
%        Mar. 24, 2010 - add extrap option (useful for stacking)
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated Mar. 24, 2010 at 14:05 GMT

% check number of arguments
msg=nargchk(2,6,nargin);
if(~isempty(msg)); error(msg); end

% check data structure
versioninfo(data,'dep');

% turn off struct checking
oldseizmocheckstate=seizmocheck_state(false);
oldversioninfocache=versioninfo_cache(true);

% attempt interpolation
try
    % check headers (versioninfo cache update)
    data=checkheader(data);
    
    % verbosity
    verbose=seizmoverbose;
    
    % number of records
    nrecs=numel(data);

    % get timing info
    leven=~strcmpi(getlgc(data,'leven'),'false');
    [b,e,npts,delta]=getheader(data,'b','e','npts','delta');

    % defaults
    if(nargin<6 || isempty(extrap)); extrap='extrap'; end
    if(nargin<5 || isempty(new_e)); new_e=b+(npts-1).*delta; end
    if(nargin<4 || isempty(new_b)); new_b=b; end
    if(nargin<3 || isempty(method)); method{1}='spline'; end

    % check and expand inputs
    if(~isnumeric(new_b))
        error('seizmo:interpolate:badInput',...
            'NEW_B must be numeric!');
    elseif(isscalar(new_b))
        new_b(1:nrecs,1)=new_b;
    elseif(numel(new_b)~=nrecs)
        error('seizmo:interpolate:badInput',...
            'NEW_B must be scalar or have the same size as DATA!');
    end
    if(~isnumeric(new_e))
        error('seizmo:interpolate:badInput',...
            'NEW_E must be numeric!');
    elseif(isscalar(new_e))
        new_e(1:nrecs,1)=new_e;
    elseif(numel(new_e)~=nrecs)
        error('seizmo:interpolate:badInput',...
            'NEW_E must be scalar or have the same size as DATA!');
    end
    if(~isnumeric(sr))
        error('seizmo:interpolate:badInput',...
            'SR must be numeric!');
    elseif(isscalar(sr))
        sr(1:nrecs,1)=sr;
    elseif(numel(sr)~=nrecs)
        error('seizmo:interpolate:badInput',...
            'SR must be scalar or have the same size as DATA!');
    end
    if(ischar(method)); method=cellstr(method); end
    if(~iscellstr(method))
        error('seizmo:interpolate:badInput',...
            'METHOD must be char/cellstr!');
    end
    if(isscalar(method))
        method(1:nrecs,1)=method;
    elseif(numel(method)~=nrecs)
        error('seizmo:interpolate:badInput',...
            'METHOD must be scalar or have the same size as DATA!');
    end
    if(ischar(extrap)); extrap=cellstr(extrap); end
    if(~any(numel(extrap)==[1 nrecs]))
        error('seizmo:interpolate:badInput',...
            ['EXTRAP must be a scalar or Nx1 ' ...
            'real-valued array or ''extrap''']);
    end
    if(isnumeric(extrap)); extrap=num2cell(extrap); end
    if(iscell(extrap))
        % check each value
        for i=1:numel(extrap)
            if(~isreal(extrap{i}) ...
                    && ~(ischar(extrap{i}) && strcmpi('extrap',extrap{i})))
                error('seizmo:interpolate:badInput',...
                    ['EXTRAP must be a scalar or Nx1 ' ...
                    'real-valued array or ''extrap''']);
            end
        end
    else
        error('seizmo:interpolate:badInput',...
            ['EXTRAP must be a scalar or Nx1 ' ...
            'real-valued array or ''extrap''']);
    end
    if(isscalar(extrap)); extrap(1:nrecs,1)=extrap; end

    % sampling interval
    dt=1./sr;
    
    % detail message
    if(verbose)
        disp('Interpolating Record(s)');
        print_time_left(0,nrecs);
    end

    % looping for each file
    depmen=nan(nrecs,1); depmin=depmen; depmax=depmen;
    for i=1:nrecs
        % save class and convert to double precision
        oclass=str2func(class(data(i).dep));

        % old timing of data
        if(leven(i)); ot=b(i)+(0:npts(i)-1).'*delta(i);
        else ot=data(i).ind; data(i).ind=[]; end

        % make new timing array
        nt=(new_b(i):dt(i):new_e(i)).';

        % interpolate and convert class back
        data(i).dep=oclass(interp1(double(ot),double(data(i).dep),...
            double(nt),method{i},extrap{i}));

        % get values (handling dataless)
        npts(i)=numel(nt);
        if(npts(i)==0)
            b(i)=nan;
            e(i)=nan;
        else
            b(i)=nt(1);
            e(i)=nt(end);
            depmen(i)=mean(data(i).dep(:));
            depmin(i)=min(data(i).dep(:));
            depmax(i)=max(data(i).dep(:));
        end
        
        % detail message
        if(verbose); print_time_left(i,nrecs); end
    end

    % update header
    data=changeheader(data,'delta',dt,'b',b,'e',e,'npts',npts,...
        'leven',true,'depmin',depmin,'depmax',depmax,'depmen',depmen);

    % toggle checking back
    seizmocheck_state(oldseizmocheckstate);
    versioninfo_cache(oldversioninfocache);
catch
    % toggle checking back
    seizmocheck_state(oldseizmocheckstate);
    versioninfo_cache(oldversioninfocache);
    
    % rethrow error
    error(lasterror)
end

end