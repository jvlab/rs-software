function vals=getinp(prompt,type,limits,default)
% vals=getinp(prompt,type,limits,default) gets an input value or values from the console and supplies a default
%
% Args: 
%   prompt (char): a prompt string, to appear after "Enter"
%
%   type (char): 'd','f','s' for integer, float, or string input; input value is required to be an integer if 'd' is used
%   
%   limits (int 1-D array or float 1-D arrray): limits(1) and limits(2) are low and high limits for input; ignored and may be empty if 'type'='s'
% 
%   default (int 1-D array or float 1-D array): default value(s) used if console response is empty
%
% Returns:
%   vals (int 1-D array, float 1-D array, or char): value(s) entered at console, or default if no value is entered
% 
if (nargin<=3) default=[]; end
vals=[];
while (isempty(vals))
   switch type
   	case {'f','d'}
      	if (length(default)>1)
         	disp(default)
         	vals=input(sprintf(cat(2,'Enter ',prompt,' (range: %',type,' to %',type,'):'),...
            	limits([1 2])));
      	elseif (length(default)==1)
         	vals=input(sprintf(cat(2,'Enter ',prompt,' (range: %',type,' to %',type,', default= %',type,'):'),...
            	limits([1 2]),default));
      	else
        		vals=input(sprintf(cat(2,'Enter ',prompt,' (range: %',type,' to %',type,'):'),...
            	limits([1 2])));
      	end
         if (isempty(vals));vals=double(default);end %double just in case default is logical (ML7)
         if (min(vals)<limits(1)) | (max(vals)>limits(2));disp('Out of range.');vals=[];end
         if type=='d'
            if (max(abs(vals-floor(vals))))>0; disp('Must be integer.');vals=[];end
         end
         
   	case 's'
      	if (length(default)>=1)
            vals=input(sprintf(cat(2,'Enter ',prompt,' (default= ',default,'):')),type);
      	else
            vals=input(sprintf(cat(2,'Enter ',prompt,':')),type);
      	end
      	if (isempty(vals));vals=default;end
   end
end

