function ifdif=compstruct(parent1,x1,parent2,x2,varargin)
%
%  ifdif=compstruct(parent1,x1,parent2,x2,varargin) compares two structures
%
%  Downloaded from matlab site as "Compare", 6/4/04; renamed to "comp_struct"
%  Uploaded by Nicholas Gigis, gigisn@netscape.net.  Original documentation follows.
%  Modified so that the text is returned as an output; empty if structures are identical
%
% Compare - This function compares two objects and outputs the
%           locations of differences between the two.  This function
%           handles nested structures, nested subarrays, arrays, strings,
%           and graphic objects.  In the case of objects, if the handles
%           are passed to x1 and x2, the properties are obtained with the
%           get function and the properties are compared.
%
%
% parent1  = name of first structure
% x1       = first structure
% parent2  = name of second structure
% x2       = second structure
% OPTS     = print and tolerance options
%            tol      = tolerance for comparison between floats
%            filename = if you wish to print the differences to a file, enter a
%                       filename for it to be save as.  Must be in single quotes.
%SPAWAR System Center Charleston
%Code 712 DF Calibraton Group
%
%  Ver: 1.0  5/19/03
%
%  13Apr21: edit made to fix bug in comparenum when inputs have different dimensions
%  26Dec25: edit made to avoid errors if grpahics objects are being compared

ifdif=[];
if nargin<4;
    error('Incorrect usage of Compare');
elseif nargin==4;
    tol=1e-5;
    fid=1;
elseif nargin==5;
    if strcmp(class(varargin{1}),'char')
        fid=fopen(varargin{1},'w');
        tol=1e-5;
    elseif strcmp(class(varargin{1}),'double');
        fid=1;
        tol=varargin{1};
    else;
        error('Incorrect usage of Compare');
    end;
elseif nargin==6;
    if strcmp(class(varargin{1}),'char') & strcmp(class(varargin{2}),'double');
        fid=fopen(varargin{1},'w');
        tol=varargin{2};
    elseif strcmp(class(varargin{2}),'char') & strcmp(class(varargin{1}),'double');
        fid=fopen(varargin{2},'w');
        tol=varargin{1};
    else;
        error('Incorrect usage of Compare');
    end;
elseif nargin>6;
    error('Incorrect usage of Compare');
end;

if ishandle(x1) & ishandle(x2);
    x1=get(x1);
    x2=get(x2);
end;

if ~isequal(x1,x2) & strcmp(class(x1),class(x2));   %if x1 is not equal to x2 and they are the same class
    if isstruct(x1);                                %if x1 a structure send to function comparestruct
        ifdif=comparestruct(parent1,x1,parent2,x2,tol,fid);
    elseif iscell(x1);                              %if x1 a cell send to function comparecell
        ifdif=comparecell(parent1,x1,parent2,x2,tol,fid);
    else;                                           %if x1 is any of the remaining classes, send to function comarenum
        ifdif=comparenum(parent1,x1,parent2,x2,tol,fid);
    end;
elseif ~strcmp(class(x1),class(x2));                %if x1 and x2 are not the same class
    ifdif=['Classes are different: ' parent1 ' is a ' class(x1) ' , and ' parent2 ' is a ' class(x2)];
end;
if fid~=1;
   fprintf(fid,[ifdif '\n']);
    fclose(fid);        
end;




function ifdif=comparenum(parent1,x1,parent2,x2,tol,fid);     %function to compare numerics, strings, logicals, & chars
ifdif=[];
if isnumeric(x1) & ~strcmp(class(x1),'double');
    x1=double(x1);
    x2=double(x2);
end;
if length(size(x1))~=length(size(x2)) %added by JV 13Apr21
    txt=['ndims(' parent1 ')~=ndims(' parent2 ')'];
    if (fid~=1)
    	fprintf(fid,[txt '\n']);
    end;
    ifdif=strvcat(ifdif,txt);
else
    if any((size(x1)==size(x2))==0);                              %check to see if lengths of x1 and x2 are not the same
        txt=['size(' parent1 ')~=size(' parent2 ')'];
        if (fid~=1)
            fprintf(fid,[txt '\n']);
        end;
        ifdif=strvcat(ifdif,txt);
    else ~any((size(x1)==size(x2))==0);                            %if x1 and x2 have the same length
        if isnumeric(x1) & isnumeric(x2) %prevent copmarison of non-numeric arguments, JV, 26Dec25
            i=find(abs(x1-x2)>tol);                             %find index where the differenxe between x1 and x2 are above a certain tolerance
            if ~isempty(i);                                     %if there are some differences
                tmp=sprintf('%d ', i);
                txt=sprintf('%s([ %s])\n',parent1,tmp);
                if (fid~=1)
                   fprintf(fid,txt);
                end;
                ifdif=strvcat(ifdif,txt);
            end;
        end;
    end;
end;
return;

function ifdif=comparecell(parent1,x1,parent2,x2,tol,fid);    %function to compare cell arrays
ifdif=[];
if any((size(x1)==size(x2))==0);                              %check to see if lengths of x1 and x2 are not the same
    txt=['size(' parent1 ') ~= size(' parent2 ')'];
    if (fid~=1)
       fprintf(fid,[txt '\n']);
    end
    ifdif=strvcat(ifdif,txt);
else ~any((size(x1)==size(x2))==0);                           %if x1 and x2 have the same length 
	for i=1:prod(size(x1));                                 %loop through the elements of x1 and x2
        if strcmp(class(x1{i}),class(x2{i}));           %if the classes of the elements x1 and x2 are the same
           if isstruct(x1{i});                          %if the elements of x1 and x2 are the structs
               tmp1=sprintf('%s{%i}',parent1,i);
               tmp2=sprintf('%s{%i}',parent2,i);
               txt=comparestruct(tmp1,x1{i},tmp2,x2{i},tol,fid);    %send the element of x1 and x2 to function comparestruct
            	ifdif=strvcat(ifdif,txt);   
            elseif iscell(x1{i});                        %if the elements of x1 and x2 are the cell arrays
               tmp1=sprintf('%s{%i}',parent1,i);
               tmp2=sprintf('%s{%i}',parent2,i);
               txt=comparecell(tmp1,x1{i},tmp2,x2{i},tol,fid);      %send the element of x1 and x2 to function comparecell
            	ifdif=strvcat(ifdif,txt);   
           else                                         %if the elements of x1 and x2 are numerics, strings, logicals, or chars
               tmp1=sprintf('%s{%i}',parent1,i);
               tmp2=sprintf('%s{%i}',parent2,i);
               txt=comparenum(tmp1,x1{i},tmp2,x2{i},tol,fid);       %send the element of x1 and x2 to function comparenum
            	ifdif=strvcat(ifdif,txt);   
           end;
       elseif ~strcmp(class(x1{i}),class(x2{i}));       %if the classes of the elements x1 and x2 are not the same
           txt=['Classes are different: ' parent1 ' is a ' class(x1) ' , and ' parent2 ' is a ' class(x2) ];
           if (fid~=1)
               fprintf(fid,[txt '\n']);
    		  end
    		  ifdif=strvcat(ifdif,txt);
       end;
	end;
end;
return;

function ifdif=comparestruct(parent1,x1,parent2,x2,tol,fid);
ifdif=[];
if any((size(x1)==size(x2))==0);                  %check to see if lengths of x1 and x2 are not the same    
    txt=['size(' parent1 ') ~= size(' parent2 ')'];
    if (fid~=1)
    	fprintf(fid,[txt '\n']);
    end
    ifdif=strvcat(ifdif,txt);
else ~any((size(x1)==size(x2))==0);               %lengths of x1 and x2 are the same
	f1=fieldnames(x1);                      %get fieldnames for x1
	f2=fieldnames(x2);                      %get fieldnames for x2
    [c, i1, i2]=setxor(f1,f2);              %find fieldnames that are not in both x1 and x2
    if ~isempty(i1) & ~isempty(i2);     %different fieldnames in both x1 and x2
        tmp11=sprintf('%s ',f1{i1});
        tmp12=sprintf('%s ',f2{i2});
        txt1=['fieldnames different: ' parent2 ' does not contain fieldname(s)\n\t' tmp11];
        txt2=['fieldnames different: ' parent1 ' does not contain fieldname(s)\n\t' tmp12];
        if (fid~=1)
           fprintf(fid,[txt1 '\n']);
           fprintf(fid,[txt2 '\n']);
    		  end
			ifdif=strvcat(ifdif,txt1,txt2);
    elseif ~isempty(i1);                %different fieldnames in x1
        tmp11=sprintf('%s ',f1{i1});
        txt=['fieldnames different: ' parent2 ' does not contain fieldname(s)\n\t' tmp11];
    		if (fid~=1)
    	     fprintf(fid,[txt '\n']);
        end
    ifdif=strvcat(ifdif,txt);
    elseif ~isempty(i2);                %different fieldnames in x2
        tmp12=sprintf('%s ',f2{i2});
        txt=['fieldnames different: ' parent1 ' does not contain fieldname(s)\n\t' tmp12 '\n'];
	     if (fid~=1)
   	 	 fprintf(fid,txt);
    	  end
    ifdif=strvcat(ifdif,txt);
    end;
    [c, i1, i2]=intersect(f1,f2);
	for i=1:prod(size(x1));                 %loop through structure array
        if ~isequal(x1(i),x2(i));       %if x1(i) is not equal to x2(i)
            for ii=1:length(c);        %loop through fieldnames
                txt1=sprintf('x1(%i).%s',i,c{ii});
                txt2=sprintf('x2(%i).%s',i,c{ii});
                if ~isequal(eval(txt1),eval(txt2)) & strcmp(class(eval(txt1)),class(eval(txt2)));   %if the values in the fieldnames of x1 and x2
                                                                                                    %are not the same and the classes of x1 and x2
                                                                                                    %are the same, then
                    if isstruct(eval(txt1));                                        %if values in the fieldnames of x1 and x2 are structs
                        dtxt1=sprintf('%s(%i).%s',parent1,i,c{ii});
                        dtxt2=sprintf('%s(%i).%s',parent2,i,c{ii});
                        txt=comparestruct(dtxt1,eval(txt1),dtxt2,eval(txt2),tol,fid);   %send to comparestruct function
                        ifdif=strvcat(ifdif,txt);
                     elseif isnumeric(eval(txt1)) | isstr(eval(txt1)) | ischar(eval(txt1)) | islogical(eval(txt1));  %if values in the fieldnames of x1 and x2
                                                                                                                    %numerics, strings, logicals, or chars
                        dtxt1=sprintf('%s(%i).%s',parent1,i,c{ii});
                        dtxt2=sprintf('%s(%i).%s',parent2,i,c{ii});
                        txt=comparenum(dtxt1,eval(txt1),dtxt2,eval(txt2),tol,fid);      %send to comparenum function
                        ifdif=strvcat(ifdif,txt);
                     elseif iscell(eval(txt1));                                      %if values in the fieldnames of x1 and x2 are cell arrays
                        dtxt1=sprintf('%s(%i).%s',parent1,i,c{ii});
                        dtxt2=sprintf('%s(%i).%s',parent2,i,c{ii});
                        txt=comparecell(dtxt1,eval(txt1),dtxt2,eval(txt2),tol,fid);     %send to function comparecell
                        ifdif=strvcat(ifdif,txt);
                     end;
                elseif ~strcmp(class(eval(txt1)),class(eval(txt2)));                %if the classes of the fieldnames of x1 and x2 are not the same
                    dtxt1=sprintf('%s(%i).%s',parent1,i,c{ii});
                    dtxt2=sprintf('%s(%i).%s',parent2,i,c{ii});
                    txt=['Classes are different: ' dtxt1 ' is a ' class(eval(txt1)) ' , and ' dtxt2 ' is a ' class(eval(txt2))];
					     if (fid~=1)
    					  		fprintf(fid,[txt '\n']);
    					  end
    					  ifdif=strvcat(ifdif,txt);
                end;
            end;
        end;
	end;
end;
return;