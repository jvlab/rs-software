# rs_disp_coordsets_demo_cars
Display datasets in an unstrucured domain (no stimulus coordinates)

run after rs_disp_coordsets_demo

See also:  [rs_disp_coordsets](rs_disp_coordsets.md)

```matlab
aux=struct;
aux.opts_disp.set_labels=data_out.sets{1}.subj_id;
for idim=2:4
aux.opts_disp.dim_select=idim;
    rs_disp_coordsets(data_out,aux); %standard plots, each dimension available
end
```

Error:

```text
Unable to resolve the name 'data_out.sets'.
```