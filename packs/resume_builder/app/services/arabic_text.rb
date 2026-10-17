# Matches any Arabic-script letter (Arabic, its supplements and presentation
# forms). The CV is English only and the ATS PDF fonts cannot draw Arabic.
module ArabicText
  PATTERN = /[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]/
end
