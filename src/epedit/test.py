# -*- coding: utf-8 -*-

import utils

# utils.test_trim('  sadf   \n\n')

# print(utils.test_to_uppercase(' kl ASDdsdf sldkf!@   '))
# print(utils.test_to_titlecase(' kl ASDdsdf sldkf!@   '))

# print(utils.test_find_char('ASDFssdfs', 'D'))

# print(utils.test_find_char_pos('SADFsdfsdf', 'D'))

# print(utils.test_fieldname_to_key('  U-Value '))

utils.test_extract_tag(r'\memo Determines which Heat Balance Algorithm will be used ie.', 'memo')

import idd

test_class_str = r'''HeatBalanceAlgorithm,
       \memo Determines which Heat Balance Algorithm will be used ie.
       \memo CTF (Conduction Transfer Functions),
       \memo EMPD (Effective Moisture Penetration Depth with Conduction Transfer Functions).
       \memo Advanced/Research Usage: CondFD (Conduction Finite Difference)
       \memo Advanced/Research Usage: ConductionFiniteDifferenceSimplified
       \memo Advanced/Research Usage: HAMT (Combined Heat And Moisture Finite Element)
       \unique-object
       \format singleLine
  A1 , \field Algorithm
       \type choice
       \key ConductionTransferFunction
       \key MoisturePenetrationDepthConductionTransferFunction
       \key ConductionFiniteDifference
       \key CombinedHeatAndMoistureFiniteElement
       \default ConductionTransferFunction
  N1 , \field Surface Temperature Upper Limit
       \type real
       \minimum 200
       \default 200
       \units C
  N2 , \field Minimum Surface Convection Heat Transfer Coefficient Value
       \units W/m2-K
       \default 0.1
       \minimum> 0.0
  N3 ; \field Maximum Surface Convection Heat Transfer Coefficient Value
       \units W/m2-K
       \default 1000
       \minimum 1.0'''

test_class_str_ext = r'''Schedule:Day:Interval,
       \extensible:2 - repeat last two fields, remembering to remove ; from "inner" fields.
       \memo A Schedule:Day:Interval contains a full day of values with specified end times for each value
       \memo Currently, is set up to allow for 10 minute intervals for an entire day.
       \min-fields 5
  A1 , \field Name
       \required-field
       \type alpha
       \reference DayScheduleNames
  A2 , \field Schedule Type Limits Name
       \type object-list
       \object-list ScheduleTypeLimitsNames
  A3 , \field Interpolate to Timestep
       \note when the interval does not match the user specified timestep a Average choice will average between the intervals request (to
       \note timestep resolution. A No choice will use the interval value at the simulation timestep without regard to if it matches
       \note the boundary or not. A Linear choice will interpolate linearly between successive values.
       \type choice
       \key Average
       \key Linear
       \key No
       \default No
 A4  , \field Time 1
       \begin-extensible
       \note "until" includes the time entered.
       \units hh:mm
 N1  , \field Value Until Time 1
 A5  ; \field Time 2
       \note "until" includes the time entered.
       \units hh:mm'''

# idd.test_match_fields(test_class_str)

# idd.test_parse_idd_class_string(test_class_str_ext)