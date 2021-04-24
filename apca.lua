--------------------------------------------------------------------------------
--[[ @preserve
----/                *** APCA VERSION for W3 and WCAG 3 ***
----/
----/   SAPC - S-Luv Advanced Perceptual Contrast - Beta Algorithm 0.98e_d12e
----/                *** With the NEW SmoothScale extension ***
----/              *** Optimized for the Font Select Extension ***
----/
----/   Functions to parse color values and determine SAPC/APCA contrast
----/   Copyright © 2019-2021 by Andrew Somers. All Rights Reserved.
----/   LICENSE: GNU AGPL v3  https:--www.gnu.org/licenses/
----/   CONTACT: For SAPC/APCA Please use the ISSUES tab at:
----/   https:--github.com/Myndex/SAPC-APCA/
-- ]]
--------------------------------------------------------------------------------
----/
----/                        SAPC Method and APCA Algorithm
----/          •••• Version 0.98e_d12e with SmoothScale™ by Andrew Somers ••••
----/
----/   GITHUB: https:--github.com/Myndex/SAPC-APCA
----/   DEVELOPER SITE: https:--www.myndex.com/WEB/Perception
----/
----/   Thanks To: 
----/   • This project references the research and work of Dr.Legge, Dr.Arditi,
----/     Dr.Lovie-Kitchin, M.Fairchild, R.Hunt, M.Stone, Dr.Poynton, L.Arend, &
----/     many others — see refs at https:--www.myndex.com/WEB/WCAG_CE17polarity
----/   • Stoyan Stefanov for his input parsing idea, Twitter @stoyanstefanov
----/   • Bruce Bailey of USAccessBoard for his encouragement, ideas, & feedback
----/   • Chris Loiselle of Oracle for getting us back on track in a pandemic
----/
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
----/
----/   *****  SAPC BLOCK  *****
----/
----/   For Evaluations, this is referred to as: SAPC-8, D-series constants
----/                S-LUV Advanced Perceptual Contrast
----/   Copyright © 2019-2021 by Andrew Somers. All Rights Reserved.
----/
----/
----/   INCLUDED Extensions or Model Features:
----/       • SAPC-8 Core Contrast
----/       • SmoothScale™ scaling technique
----/       • SoftToe black level soft clamp
----/
----/   NOT INCLUDED — This Version Does NOT Have These Extensions:
----/       • Color Vision Module
----/       • Spatial Frequency Module
----/       • Light Adaptation Module
----/       • Dynamics Module
----/       • Alpha Module
----/       • Personalization Module
----/       • Multiway Module
----/       • DynaFont™ font display
----/       • ResearchMode middle contrast explorer
----/       • ResearchMode static target
----/       • CIE function suite
----/       • SAPColor listings and sorting suite
----/       • RGBcolor() colorString parsing
----/
----/
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
------------------------------------------------------------------------------/
----/  BEGIN SAPC/APCA CONTRAST BLOCK  \--------------------------------------
----                                    \------------------------------------


----------------------------------------------------------------------------
----/ SAPC Function with SmoothScale  \------------------------------------
----                                   \----------------------------------
--/

----/ *** Polarity is Important: do not mix up background and text *** ----/

----/  Input value must be integer in RGB order (RRGGBB for 0xFFFFFF)  ----/

            ----/  DO NOT use a Y from any other method  ----/
local APCA = {}

function APCA.contrast (background, text)

        Rbg = (background & 0xFF0000) >> 16
        Gbg = (background & 0x00FF00) >> 8
        Bbg = (background & 0x0000FF)

        Rtxt = (text & 0xFF0000) >> 16
        Gtxt = (text & 0x00FF00) >> 8
        Btxt = (text & 0x0000FF)


        ----/  MAGICAL NUMBERS  ------------------------------/

        ----/  sRGB Conversion to Relative Luminance (Y)  ----/

  mainTRC = 2.4 -- Transfer Curve (aka "Gamma") for sRGB linearization
                      -- Simple power curve vs piecewise described in docs
                     -- Essentially, 2.4 best models actual display
                    -- characteristics in combination with the total method

  mainTRCencode = 0.41666666666666666667 -- = 1.0/mainTRC

  Rco = 0.2126729        -- sRGB Red Coefficient (from matrix)
  Gco = 0.7151522       -- sRGB Green Coefficient (from matrix)
  Bco = 0.0721750        -- sRGB Blue Coefficient (from matrix)


        ----/  For Finding Raw SAPC Contrast from Relative Luminance (Y)  ----/

  normBG = 0.55          -- Constants for SAPC Power Curve Exponents
  normTXT = 0.58         -- One pair for normal text, and one for reverse
  revTXT = 0.57          -- These are the "beating heart" of SAPC
  revBG = 0.62


        ----/  For Clamping and Scaling Values  ----/

  blkThrs = 0.03         -- Level that triggers the soft black clamp
        blkClmp = 1.45         -- Exponent for the soft black clamp curve
        deltaYmin = 0.0005     -- Lint trap
        scaleBoW = 1.25        -- Scaling for dark text on light
        scaleWoB = 1.25        -- Scaling for light text on dark
        loConThresh = 0.078    -- Threshold for new simple offset scale
        loConFactor = 12.82051282051282    -- = 1/0.078,
        loConOffset = 0.06     -- The simple offset
        loClip = 0.001         -- Output clip (lint trap #2)


        -- We are only concerned with Y at this point
        -- Ybg and Ytxt: divide sRGB to 0.0-1.0 range, linearize,
        -- and then apply the standard coefficients and sum to Y.
        -- Note that the Y we create here is unique and designed
        -- exclusively for SAPC. Do not use Y from other methods.
    
    Ybg =   math.pow(Rbg/255.0, mainTRC) * Rco +
                math.pow(Gbg/255.0, mainTRC) * Gco +
                math.pow(Bbg/255.0, mainTRC) * Bco

    Ytxt =  math.pow(Rtxt/255.0, mainTRC) * Rco +
                math.pow(Gtxt/255.0, mainTRC) * Gco +
                math.pow(Btxt/255.0, mainTRC) * Bco

    SAPC = 0.0             -- For holding raw SAPC values
    outputContrast = 0.0   -- For weighted final values


    ----/ TUTORIAL  ----/

    -- Take Y and soft clamp black, return 0 for very close luminances
    -- determine polarity, and calculate SAPC raw contrast
    -- Then apply the output scaling 

    -- Note that reverse contrast (white text on black)
    -- intentionally returns a negative number
    -- Proper polarity is important! 


----------   BLACK SOFT CLAMP & INPUT CLIP  --------------------------------

        -- Soft clamp Y when near black.
        -- Now clamping all colors to prevent crossover errors
    Ytxt = (Ytxt > blkThrs) and Ytxt or (Ytxt + math.pow(blkThrs - Ytxt, blkClmp))

    Ybg = (Ybg > blkThrs) and Ybg or (Ybg + math.pow(blkThrs - Ybg, blkClmp))


        ----/   Return 0 Early for extremely low ∆Y (lint trap #1) ----/
    if (math.abs(Ybg - Ytxt) < deltaYmin) then
        outputcontrast = 0
    elseif ( Ybg > Ytxt ) then     -- For normal polarity, black text on white

            ----/ Calculate the SAPC contrast value and scale
        SAPC = ( math.pow(Ybg, normBG) - math.pow(Ytxt, normTXT) ) * scaleBoW

                ----/ NEW! SAPC SmoothScale™
               -- Low Contrast Smooth Scale Rollout to prevent polarity reversal
              -- and also a low clip for very low contrasts (lint trap #2)
             -- much of this is for very low contrasts, less than 10
            -- therefore for most reversing needs, only loConOffset is important
        if (SAPC < loClip) then
            outputContrast = 0.0
        elseif ( SAPC < loConThresh ) then
            outputContrast = SAPC - SAPC * loConFactor * loConOffset
        else
            outputContrast = SAPC - loConOffset
        end

    else      -- For reverse polarity, light text on dark
                -- WoB should always return negative value.

        SAPC = ( math.pow(Ybg, revBG) - math.pow(Ytxt, revTXT) ) * scaleWoB

        if (SAPC > -loClip) then
            outputContrast = 0.0
        elseif ( SAPC > -loConThresh ) then
            outputContrast = SAPC - SAPC * loConFactor * loConOffset
        else
            outputContrast = SAPC + loConOffset
        end
    end

    return  outputContrast * 100

end -- Close APCAcontrast()
--
-- Test values to check
--  text, background, expected value from https://github.com/Myndex/SAPC-APCA Readme
--
-- local function assertsame( a, b )
--     print (math.abs( a - b ) < 0.000000000001)
--   end
-- assertsame(APCA.contrast(0xffffff, 0x888888), 66.89346308821438)
-- assertsame(APCA.contrast(0x000000, 0xaaaaaa), -60.438571788907524)
-- assertsame(APCA.contrast(0x112233, 0xddeeff), -98.44863435731266)
-- assertsame(APCA.contrast(0x223344, 0x112233), 1.276075977788573)

return APCA
----\                            ------------------------------------------/\
----/\  END OF SAPC/APCA BLOCK  --------------------------------------------/\
------------------------------------------------------------------------------\
------------------------------------------------------------------------------/\

