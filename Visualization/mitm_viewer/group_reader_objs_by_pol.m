function [ grouped_indices, new_reader_array ] = group_reader_objs_by_pol( reader_array )
%GROUP_READER_OBJS_BY_POL Consolidate readers into sets that are
%polarimetric channels from the same collect
%
% Author: Wade Schwartzkopf, NGA/IDT
%
% //////////////////////////////////////////
% /// CLASSIFICATION: UNCLASSIFIED       ///
% //////////////////////////////////////////

grouped_indices={};
reader_indices=1:length(reader_array);
alreadymatched=false(size(reader_indices));
for i=1:length(reader_indices)
    if not(alreadymatched(i))
        group=i; % Build group of all channels that match reader i
        for j=(i+1):length(reader_indices) % Check all other readers for match
            if not(alreadymatched(j))&&...
                    is_same_collect(reader_array{i},reader_array{j})&&...
                    different_polarimetric_channel(reader_array{i},reader_array{j})
                group=[group j]; % Save reader j as in the same group as i
                alreadymatched(j)=true; % Don't match to anything else later
            end
        end
        grouped_indices{end+1}=group;
    end
end

% Stack separate readers to be single reader with multiband output
if nargout>1
    new_reader_array=cell(length(grouped_indices),1);
    for i=1:length(grouped_indices)
        if length(grouped_indices{i})>1
            metadata=reader_array{grouped_indices{i}(1)}.get_meta();
            metadata.ImageFormation.TxRcvPolarizationProc=...
                {metadata.ImageFormation.TxRcvPolarizationProc};
            for j=2:length(grouped_indices{i})
                temp_meta=reader_array{grouped_indices{i}(j)}.get_meta();
                metadata.ImageFormation.TxRcvPolarizationProc{end+1}=...
                    temp_meta.ImageFormation.TxRcvPolarizationProc;
            end
            new_reader_array{i}=stack_readers({reader_array{grouped_indices{i}}});
            new_reader_array{i}.get_meta=@() metadata;
        else % If not multiples, just copy reader
            new_reader_array{i}=reader_array{grouped_indices{i}(1)};
        end
    end
end

end

% Checks if two images are from the same collect
function boolean_out = is_same_collect( reader1, reader2 )
    reader1_meta=reader1.get_meta();
    reader2_meta=reader2.get_meta();
    if isfield(reader2_meta, 'GeoData') && isfield(reader2_meta.GeoData, 'SCP')
        scp2_ecf = [reader2_meta.GeoData.SCP.ECF.X; ...
            reader2_meta.GeoData.SCP.ECF.Y; reader2_meta.GeoData.SCP.ECF.Z];
        try
            essentially_same = norm(scp2_ecf - ... % Two SCPs project to same point
                point_image_to_ground([reader1_meta.ImageData.SCPPixel.Row; ...
                reader1_meta.ImageData.SCPPixel.Col], reader1_meta, ...
                'projection_type','plane','gref',scp2_ecf))<1;
        catch
            try
                scp1_ecf = [reader1_meta.GeoData.SCP.ECF.X; ...
                    reader1_meta.GeoData.SCP.ECF.Y; reader1_meta.GeoData.SCP.ECF.Z];
                essentially_same = norm(scp2_ecf - scp1_ecf)<1; % Two SCPs are same point
            catch
                boolean_out = false;        
            end
        end
    end
    try % May not have all the necessary fields
        % Size same, sensor same, start time same, same place
        boolean_out =...
            ... % Images are same size
            isfield(reader1_meta,'ImageData')&&...
            isfield(reader2_meta,'ImageData')&&...
            reader1_meta.ImageData.NumRows==reader2_meta.ImageData.NumRows&&...
            reader1_meta.ImageData.NumCols==reader2_meta.ImageData.NumCols&&...
            ... % Images are from same sensor
            isfield(reader1_meta,'CollectionInfo')&&...
            isfield(reader1_meta.CollectionInfo,'CollectorName')&&...
            isfield(reader2_meta,'CollectionInfo')&&...
            isfield(reader2_meta.CollectionInfo,'CollectorName')&&...
            strcmp(reader1_meta.CollectionInfo.CollectorName,reader2_meta.CollectionInfo.CollectorName)&&...
            ... % Images are at the same time
            isfield(reader1_meta,'Timeline')&&...
            isfield(reader1_meta.Timeline,'CollectStart')&&...
            isfield(reader2_meta,'Timeline')&&...
            isfield(reader1_meta.Timeline,'CollectStart')&&...
            ((abs(reader1_meta.Timeline.CollectStart-reader2_meta.Timeline.CollectStart)*24*60*60)<0.01)&&...
            ... % Images are of the same place (for multi-segment datasets)
            isfield(reader1_meta,'GeoData')&&...
            isfield(reader1_meta.GeoData,'SCP')&&...
            isfield(reader1_meta.GeoData.SCP,'LLH')&&...
            isfield(reader2_meta,'GeoData')&&...
            isfield(reader2_meta.GeoData,'SCP')&&...
            isfield(reader2_meta.GeoData.SCP,'LLH')&&...
            ((abs(reader1_meta.GeoData.SCP.LLH.Lat-reader2_meta.GeoData.SCP.LLH.Lat)<1e-5&&...
            abs(reader1_meta.GeoData.SCP.LLH.Lon-reader2_meta.GeoData.SCP.LLH.Lon)<1e-5&&...
            abs(reader1_meta.GeoData.SCP.LLH.HAE-reader2_meta.GeoData.SCP.LLH.HAE)<1) || ...
            essentially_same);
    catch
        boolean_out = false;
    end
end

% Check if two images are different polarimetric channels
function boolean_out = different_polarimetric_channel( reader1, reader2 )
    reader1_meta=reader1.get_meta();
    reader2_meta=reader2.get_meta();
    try
        boolean_out =...
            isfield(reader1_meta,'ImageFormation')&&...
            isfield(reader1_meta.ImageFormation,'TxRcvPolarizationProc')&&...
            isfield(reader2_meta,'ImageFormation')&&...
            isfield(reader2_meta.ImageFormation,'TxRcvPolarizationProc')&&...
            ~strcmp(reader1_meta.ImageFormation.TxRcvPolarizationProc,...
            reader2_meta.ImageFormation.TxRcvPolarizationProc);
    catch
        boolean_out = false;
    end
end

% //////////////////////////////////////////
% /// CLASSIFICATION: UNCLASSIFIED       ///
% //////////////////////////////////////////