function vals=getinp(prompt,type,limits,default)
%
% vals=getinp(prompt,type,limits,default) gets an input value from the console
%
% prompt: the prompt string
% type='f','d','s' for float or integer conversion, or strings
%  result forced to be integer if d is used
% limits([1 2]): low and high limit, ignored for strings
% default: default value if entry is empty
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

