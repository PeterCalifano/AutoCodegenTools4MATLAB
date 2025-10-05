classdef EnumColumnICD
   enumeration
       Hierarchy
       SignalName
       DataType
       Dimensions
       DimensionsMode
       Unit
       Complexity
       SamplingMode
       SampleTime
       Min
       Max
       Description
       DefaultValue
       IsBus
       ReferencedBus
       Properties
       Row
       Variables
       Telemetry
       Notes
   end

   methods (Static, Access = public)
       function varCol = GetDefaultValue(charColName, dNumRows)
           arguments
               charColName {mustBeText}
               dNumRows    (1,1) {mustBePositive}
           end
           switch lower(charColName)
               case {"isbus", "telemetry"}         % booleans if expected
                   varCol = false(dNumRows,1);

               case {"min","max","sampletime"}     % numeric if expected
                   varCol = NaN(dNumRows, 1);

               otherwise                           % default to string
                   varCol = strings(dNumRows, 1);
           end
       end
   end
end
