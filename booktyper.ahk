#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input
SetWorkingDir %A_ScriptDir%  ;Ensures a consistent starting directory.
FileEncoding, UTF-8


FilePath := "" ;Represents the text file to be read
Version := "" ;Represents the version to work with
MAX_PIXELS_PER_LINE := 114
MAX_LINES := 14
MAX_PAGES := 100 ;100 pages per book in Java Edition
InputFile := "" ;Represents the text the program is iterating through

FillLines := false ;If set to true, the current word will be broken between lines/pages instead of saved
SaveCurrentBookProgress := false ;If set to true, the pixels typed, lines typed, and pages typed will not be reset after the pasting is finished
PasteText := true ;If set to false, the letters will be typed one by one

FileReady := true
TextReady := false

;Represents the init variables a user is able to change in the settings GUI

;Array Value 1: Location of variable in settings.ini
;Array Value 2: Default variable in "bedrock" edition
;Array Value 3: Default variable in "java" edition

;Reserved location name "REF" means the GUI variable is directly linked to another variable, listed next

fluidvars := {"MAX_LINES": ["pagelines", 14, 14]
			, "MAX_PAGES": ["bookpages", 50, 100]
			, "FillLines": ["filllines", 0, 0]
			, "SaveCurrentBookProgress": ["maintain", 0, 0] ;UNIMPLEMENTED
			, "PasteText": ["pastetext", 1, 1]
			, "MAX_LINESData": ["REF", "MAX_LINES"]
			, "MAX_PAGESData": ["REF", "MAX_PAGES"]}



CustomIni(ByRef fluidvars) { ;Only called when custom settings are picked

	For Option, Presets in fluidvars
	{
		if (Presets[1] != "REF") {
			IniLoc := Presets[1]
			IniRead, %Option%, settings.ini, settings, %IniLoc%
			%Option% += 0
		}
	}
}

StartWrite(FilePath, Version) { ;Should only be called when hotkey is started; "shadow" save
	
	if (FilePath = "Select a file..." or FilePath = "") {
		IniWrite, "", settings.ini, settings, filename
	}
	else {
		IniWrite, %FilePath%, settings.ini, settings, filename
	}
	IniWrite, %Version%, settings.ini, settings, version
}

CustomWrite(fluidvars) { ;Should only be called when save is pressed on settings

	IniWrite, custom, settings.ini, settings, version

	For Option, Presets in fluidvars
	{
		if (Presets[1] != "REF") {
			OptionValue := %Option%
			IniLoc := Presets[1]
			IniWrite, %OptionValue%, settings.ini, settings, %IniLoc%
		}
	}
}



IniRead, FilePath, settings.ini, settings, filename
if (FilePath = "ERROR" or FilePath = "") {
	FilePath := "Select a file..."
	FileReady := false
}

IniRead, Version, settings.ini, settings, version
if (Version = "bedrock") {
	MAX_PAGES := 50
}
else if (Version = "custom") {
	CustomIni(fluidvars)
}
else {
	Version := "java" ;Default version of minecraft
}



Values := {} ;Consists of all valid unicode numbers and their values

FileRead, DictFile, dict.txt
Loop, Parse, DictFile, `n ;Goes through the file, splitting each subsection by newline
{
	Split := StrSplit(A_LoopField, ":")
	Values[Split[1]] := Split[2] ;AHK arrays begin with 1, not 0; Also, the string numbers seem to be implicitly cast into integers
}

CurrentWord := "" ;The word currently being typed (split by spaces)
CurrentWordPixels := 0
PixelsTyped := 0 ;Keeps track of the space typed in a single line, or space to be typed in a single line
LinesTyped := 0 ;Keeps track of how many total lines were filled, or to be filled
PagesTyped := 0 ;How many pages in total were typed
StartIndex := 1 ;Represents the beginning of the input file to begin pasting; changes from 0 if not everything fits into one book
WordStartIndex := 1 ;Represents the beginning of a word



Gui, Presets:New, , BookTyper
Gui, Presets:Add, Text, X120 Y10 vTopText, Select a text file to paste:
Gui, Presets:Add, Edit, X20 Y40 W285 vSelectText, %FilePath%
GuiControl, Presets:Disable, SelectText ;Users should not be able to "type" files, as this could easily lead to invalid directories
Gui, Presets:Add, Button, X315 Y39 gSelectButtonCMD vSelectButton, 📁
Gui, Presets:Add, Text, X95 Y80 vBottomText, Or`, enter some text in the field below...
Gui, Presets:Add, Edit, X20 Y110 W320 H100 vEnterField gEnterFieldCMD,
Gui, Presets:Add, Button, X20 Y260 gStartButtonCMD vStartTextButton, Begin With Text
Gui, Presets:Add, Button, X150 Y260 gStartButtonCMD vStartFileButton, Begin With File
Gui, Presets:Add, Button, X271 Y260 vSettingsButton gSettingsButtonCMD, Customize...
Gui, Presets:Add, Radio, X20 Y230 vVersionsGroup gJavaCMD, Java Edition
Gui, Presets:Add, Radio, X120 Y230 gBedrockCMD, Bedrock Edition
Gui, Presets:Add, Radio, X240 Y230 gCustomizeCMD, Custom Settings



ChangesMade := false ;Variable to keep track of when the user is allowed to press save

Gui, Customize:New, , Options
Gui, Customize:Add, Text, X20 Y20 vLinesText, Lines per page:
Gui, Customize:Add, Slider, X20 Y40 Center Range1-14 TickInterval7 AltSubmit gSliderCMD vMAX_LINES, %MAX_LINES% ;Users can redefine constants
Gui, Customize:Add, Edit, X150 Y50 W35 vMAX_LINESData, %MAX_LINES% ;The text showing the value of the constant is that constant var name concatenated with Data
GuiControl, Customize:Disable, MAX_LINESData
Gui, Customize:Add, Text, X20 Y90 vPagesText, Pages per book:
Gui, Customize:Add, Slider, X20 Y110 Center Range1-100 TickInterval50 AltSubmit gSliderCMD vMAX_PAGES, %MAX_PAGES%
Gui, Customize:Add, Edit, X150 Y120 W35 vMAX_PAGESData, %MAX_PAGES%
GuiControl, Customize:Disable, MAX_PAGESData
Gui, Customize:Add, CheckBox, X20 Y170 vSaveCurrentBookProgress gUpdateCMD, Maintain current book progress
GuiControl, Customize:, SaveCurrentBookProgress, %SaveCurrentBookProgress%
Gui, Customize:Add, CheckBox, X20 Y195 vFillLines gUpdateCMD, Always fill lines
GuiControl, Customize:, FillLines, %FillLines%
Gui, Customize:Add, CheckBox, X20 Y220 vPasteText gUpdateCMD, Copy text to clipboard and paste (disabling makes it slower)
GuiControl, Customize:, PasteText, %PasteText%
Gui, Customize:Add, Button, X20 Y255 vSaveButton gSaveCMD, Save
GuiControl, Customize:Disable, SaveButton
Gui, Customize:Add, Button, X70 Y255 vCustReturn gCustReturnCMD, Return



Gui, Paster:New, , BookTyper - Active
Gui, Paster:Add, Text, X110 Y20, In Minecraft, paste text using CTRL + Shift + B.
Gui, Paster:Add, Text, X25 Y40, To clear all the text from a book, go to the starting page and press CTRL + Shift + N.
Gui, Paster:Add, Progress, X20 Y67 W370 H20 cBlue BackgroundCFCFCF vTypingCompletion, 0
Gui, Paster:Add, Edit, X400 Y67 W35 H20 vCompletionText, 0`%
GuiControl, Paster:Disable, CompletionText
Gui, Paster:Add, Text, X20 Y100, Current Page:
Gui, Paster:Add, Text, X95 Y100 vCurrentPage, 1 ;Program always starts typing at page 1, line 1
Gui, Paster:Add, Text, X120 Y100, Current Line:
Gui, Paster:Add, Text, X190 Y100 vCurrentLine, 1
Gui, Paster:Add, Text, X210 Y100, Pixels Left (on line):
Gui, Paster:Add, Text, X310 Y100 vCurrentPixels, %MAX_PIXELS_PER_LINE% ;Should be 114 unless the user changes it
Gui, Paster:Add, Text, X350 Y100, Iterations:
TimesPasted := 0
Gui, Paster:Add, Text, X405 Y100 vTimesPasted, 0
Gui, Paster:Add, Button, X20 Y130 vActiveReturn gActiveReturnCMD, Return


UpdateValues(PixelsTyped, LinesTyped, PagesTyped, PercentageComplete, MAX_PIXELS_PER_LINE, ByRef TimesPasted) { ;Called once hotkey is finished typing

	CurrentPage := (1 + PagesTyped)
	CurrentLine := (1 + LinesTyped)
	CurrentPixels := (MAX_PIXELS_PER_LINE - PixelsTyped)
	
	GuiControl, Paster:, CurrentPage, %CurrentPage%
	GuiControl, Paster:, CurrentLine, %CurrentLine%
	GuiControl, Paster:, CurrentPixels, %CurrentPixels%
	
	GuiControl, Paster:, TypingCompletion, %PercentageComplete%
	GuiControl, Paster:, CompletionText, %PercentageComplete%`%
	
	if (PercentageComplete = 100) {
		TimesPasted += 1
		GuiControl, Paster:, TimesPasted, %TimesPasted%
	}
}



if (Version = "java") {
	GuiControl, Presets:, Java Edition, 1
}
else if (Version = "bedrock") {
	GuiControl, Presets:, Bedrock Edition, 1
}
else {
	GuiControl, Presets:, Custom Settings, 1
}

if (not FileReady) {
	GuiControl, Presets:Disable, StartFileButton
}

if (not TextReady) {
	GuiControl, Presets:Disable, StartTextButton
}

Gui, Presets:Show, W360 H300 Center
return ;Start the GUI

PresetsGuiClose:
ExitApp

CustomizeGuiClose:
ExitApp

PasterGuiClose:
ExitApp



SelectButtonCMD: ;********** Called when file select button is clicked
FileSelectFile, FilePath, 3, , , *.txt ;Only able to select text files that exist
if (FilePath != "") {
	GuiControl, Presets:, SelectText, %FilePath% ;Updates the text shown to the file path chosen
	if (not FileReady) {
		FileReady := true
		GuiControl, Presets:Enable, StartFileButton
	}
}
return


EnterFieldCMD: ;********** Called when text is typed into the enter field
Gui, Presets:Submit, NoHide
if (EnterField != "" and (not TextReady)) {
	TextReady := true
	GuiControl, Presets:Enable, StartTextButton
}
else if (EnterField = "") {
	TextReady := false
	GuiControl, Presets:Disable, StartTextButton
}
return


StartButtonCMD: ;Begin the hotkey, using the text entered as input
Gui, Presets:Submit, NoHide
if (A_GuiControl = "StartFileButton") { ;Read from file selected
	
	try {
		FileRead, InputFile, %FilePath%
	}
	catch e {
		MsgBox, An error occured loading the file. Either the destination no longer exists, is inaccessible by the script, or cannot be loaded in memory.
		
		ErrorLevel := 0
		return
	}
	
	if (InputFile = "") {
		MsgBox, Error: File given is empty.
		return
	}
}
else { ;Read from text entered
	InputFile := EnterField
}

StartWrite(FilePath, Version)
Gui, Presets:Hide
Gui, Paster:Show, W450 H170 Center
return


JavaCMD: ;********** Called when Java Edition radio button is clicked
if (Version != "java") {

	for Options, Presets in fluidvars
	{
		if (Presets[1] != "REF") {
			StandVal := Presets[3] ;Standard java value
			%Options% := StandVal
			GuiControl, Customize:, %Options%, %StandVal%
		}
		else {
			StandVal := fluidvars[Presets[2]][3]
			GuiControl, Customize:, %Options%, %StandVal%
		}
	}
	Version := "java"

	if (ChangesMade) {
		GuiControl, Customize:Disable, SaveButton
		ChangesMade := false
	}
}
return


BedrockCMD: ;********** Called when Bedrock Edition radio button is clicked
if (Version != "bedrock") {
	
	for Options, Presets in fluidvars
	{
		if (Presets[1] != "REF") {
			StandVal := Presets[2] ;Standard bedrock value
			%Options% := StandVal
			GuiControl, Customize:, %Options%, %StandVal%
		}
		else {
			StandVal := fluidvars[Presets[2]][2]
			GuiControl, Customize:, %Options%, %StandVal%
		}
	}
	Version := "bedrock"

	if (ChangesMade) {
		GuiControl, Customize:Disable, SaveButton
		ChangesMade := false
	}
}
return


CustomizeCMD: ;********** Called when Custom Settings radio button is clicked
if (Version != "custom") {
	
	CustomIni(fluidvars)
	for Options, Presets in fluidvars
	{
		if (Presets[1] != "REF") {
			StandVal := %Options% ;Retrieves the value stored in the updated variable
			GuiControl, Customize:, %Options%, %StandVal%
		}
		else {
			StandVal := Presets[2] ;Due to this, all "REF"s should be placed before the "normal" variables
			StandVal := %StandVal%
			GuiControl, Customize:, %Options%, %StandVal%
		}
	}
	Version := "custom"

	if (ChangesMade) {
		GuiControl, Customize:Disable, SaveButton
		ChangesMade := false
	}
}
return


SettingsButtonCMD: ;Switch to settings window
Gui, Presets:Hide
Gui, Customize:Show, W560 H300 Center
return



SaveCMD:
Gui, Customize:Submit, NoHide
CustomWrite(fluidvars)
GuiControl, Customize:Disable, SaveButton
ChangesMade := false
return


SliderCMD:
gosub UpdateCMD
if (not (A_GuiEvent = "Normal")) { ;When the Gui event is "normal", that means the user has finished sliding, but the variable has already been updated before; therefore accounting for this is redundant
	Gui, Customize:Submit, NoHide ;Save the variables without closing the window
	NewVal := %A_GuiControl%
	GuiControl, Customize:, %A_GuiControl%Data, %NewVal% ;A_GuiControl contains the variable name that called the function; this updates that variable name + data - a text box where the number value should be stored
}
return


UpdateCMD: ;General update command; updates the changes made variable as well as checkboxes if needed
if (not ChangesMade) {
	GuiControl, Customize:Enable, SaveButton
	ChangesMade := true
}

if (Version != "custom") { ;Update version; now that user is customizing the settings it should be set to custom
	Version := "custom"
	GuiControl, Presets:, Custom Settings, 1
}
return


CustReturnCMD: ;Return to general window from settings
Gui, Customize:Hide
Gui, Presets:Show, W360 H300 Center
return



ActiveReturnCMD: ;Return to general window from active mode
CurrentWord := "" ;Reset everything
CurrentWordPixels := 0
PixelsTyped := 0
LinesTyped := 0
PagesTyped := 0
StartIndex := 1
WordStartIndex := 1
Gui, Paster:Hide
Gui, Presets:Show, W360 H300 Center
return



#IfWinExist BookTyper - Active
^+b::

PreviousDelay := A_KeyDelay
BookEnded := false ;When the book ends, do not type the current word out
clipboardMemory := clipboard
clipboard := "" ;Utilized in pasting mode
WaitVal := 25 ;Milliseconds to wait before pressing the paste button
Sleep, %WaitVal%

if (PasteText) {
	SendMode Event ;Pasting mode is less likely to bug out this way
	SetKeyDelay, %WaitVal%
}

;SPECIAL CHARACTERS: `n, space, paragraph sign and chars after it



TextSendBookEnd(CurrentWord, PasteText, ByRef WordStartIndex, StartIndex) {
	if (not PasteText) {
		Loop, Parse, CurrentWord 
		{
			Send, %A_LoopField%
		}
	}
	else {
		clipboard := clipboard . CurrentWord
		Sleep, %WaitVal%
		Send, ^v
		Sleep, %WaitVal%
		clipboard := ""
	}
	WordStartIndex := StartIndex + 1
}


TextSendPageEnd(CurrentWord, PasteText, ByRef WordStartIndex, StartIndex) {
	if (not PasteText) {
		Loop, Parse, CurrentWord ;Clear text lines
		{
			Send, %A_LoopField%
		}
		Send, {PgDn}
	}
	else {
		clipboard := clipboard . CurrentWord
		Sleep, %WaitVal%
		Send, ^v ;Paste
		Send, {PgDn}
		Sleep, %WaitVal%
		clipboard := ""
	}
	WordStartIndex := StartIndex + 1
}


TextSendLineEnd(CurrentWord, PasteText, ByRef WordStartIndex, StartIndex) {
	if (not PasteText) {
		Loop, Parse, CurrentWord ;Send the word copied whenever there is a enter or space created
		{
			Send, %A_LoopField%
		}
		Send, {Enter}
	}
	else {
		clipboard := clipboard . CurrentWord . "`n"
	}
	WordStartIndex := StartIndex + 1
}


TextSendStandard(CurrentWord, PasteText, ByRef WordStartIndex, StartIndex) {
	if (not PasteText) {
		Loop, Parse, CurrentWord
		{
			Send, %A_LoopField%
		}
		Send, {Space}
	}
	else {
		clipboard := clipboard . CurrentWord . " "
	}
	WordStartIndex := StartIndex + 1
}



ReadText := SubStr(InputFile, StartIndex)
Loop, Parse, ReadText
{
	if (Values.HasKey(Ord(A_LoopField))) { ;Character is accounted for
		
		Width := 0
		
		if (A_LoopField = "`n") {
			Width := (MAX_PIXELS_PER_LINE - PixelsTyped) + 1
		}
		else {
			Width := Values[Ord(A_LoopField)]
		}
		
		Width += 0 ;Cast width into an integer ;NOTE: Numeric strings stored in variables are interpreted as integers, but are not actually???
		Width += 1 ;Counts the small pixel space after each character
		
		if ((PixelsTyped + Width) > MAX_PIXELS_PER_LINE) { ;Line finished; This should always be true when Width = `n
			if ((LinesTyped + 1) = MAX_LINES) { ;Page finished
				if ((PagesTyped + 1) = MAX_PAGES) { ;Book finished
					
					if (CurrentWordPixels = PixelsTyped or (CurrentWordPixels + Width) > MAX_PIXELS_PER_LINE or FillLines) { ;Deal with "text lines" first; ######## MAKE SURE TO SAVE THE LAST LETTER TYPED FOR ANOTHER BOOK
						
						TextSendBookEnd(CurrentWord, PasteText, WordStartIndex, StartIndex)
						
						if (A_LoopField = " " or A_LoopField = "`n") {
							CurrentWord := ""
						}
						else {
							CurrentWord := "" . A_LoopField
						}
					}
					else { ;Save current word if it can be typed in the next line
					
						if (A_LoopField = " " or A_LoopField = "`n") {
							
							TextSendBookEnd(CurrentWord, PasteText, WordStartIndex, StartIndex)
							
							CurrentWord := ""
						}
						else {
							
							if (PasteText) { ;If pasting mode is on, paste the current clipboard which does NOT contain the current word
								Sleep, %WaitVal%
								Send, ^v
								Sleep, %WaitVal%
								clipboard := ""
							}

							CurrentWord := CurrentWord . A_LoopField
						}
					}
					
					BookEnded = true ;Resets the current word pixels, pixels typed, and lines typed at the end; doesn't have to do it here
					Break
				}
				else { ;Book unfinished, next page
					
					if (CurrentWordPixels = PixelsTyped or (CurrentWordPixels + Width) > MAX_PIXELS_PER_LINE or FillLines) {
						
						TextSendPageEnd(CurrentWord, PasteText, WordStartIndex, StartIndex)
						
						if (A_LoopField = " " or A_LoopField = "`n") {
							
							CurrentWord := ""
							CurrentWordPixels := 0
							PixelsTyped := 0
							LinesTyped := 0
						}
						else { ;Normal character
							
							CurrentWord := "" . A_LoopField
							CurrentWordPixels := Width
							PixelsTyped := Width
							LinesTyped := 0
						}
					}
					else {
								
						if (A_LoopField = " " or A_LoopField = "`n") {
						
							TextSendPageEnd(CurrentWord, PasteText, WordStartIndex, StartIndex)
							
							CurrentWord := ""
							CurrentWordPixels := 0
							PixelsTyped := 0
							LinesTyped := 0
						}
						else {
							
							if (PasteText) {
								Sleep, %WaitVal%
								Send, ^v
								Send, {PgDn}
								Sleep, %WaitVal%
								clipboard := ""
							}
							else {
								Send, {PgDn}
							}
							
							CurrentWord := CurrentWord . A_LoopField
							CurrentWordPixels += Width
							PixelsTyped := CurrentWordPixels
							LinesTyped := 0
						}
					}
					
					PagesTyped++
					
				}
			}
			else { ;Page unfinished, next line
				
				if (CurrentWordPixels = PixelsTyped or (CurrentWordPixels + Width) > MAX_PIXELS_PER_LINE or FillLines) { ;Either not enough space on this line or the next for the word
					
					TextSendLineEnd(CurrentWord, PasteText, WordStartIndex, StartIndex)
					
					if (A_LoopField = " " or A_LoopField = "`n") {
						
						CurrentWord := ""
						CurrentWordPixels := 0
						PixelsTyped := 0
					}
					else {
						
						CurrentWord := "" . A_LoopField
						CurrentWordPixels := Width
						PixelsTyped := Width
					}
				}
				else { ;Default
					
					if (A_LoopField = " " or A_LoopField = "`n") {

						TextSendLineEnd(CurrentWord, PasteText, WordStartIndex, StartIndex)
						
						CurrentWord := ""
						CurrentWordPixels := 0
						PixelsTyped := 0
					}
					else {
					
						if (not PasteText) {
							Send, {Enter}
						}
						else {
							clipboard := clipboard . "`n"
						}
						
						CurrentWord := CurrentWord . A_LoopField
						CurrentWordPixels += Width
						PixelsTyped := CurrentWordPixels
					}
				}
				
				LinesTyped++
				
			}
		}
		else { ;Line unfinished, continue "typing"
		
			if (A_LoopField = " ") { ;`n is not accounted for here, as it should be impossible that a newline does not finish the current line
			
				TextSendStandard(CurrentWord, PasteText, WordStartIndex, StartIndex)

				CurrentWord := ""
				CurrentWordPixels := 0
			}
			else {
			
				CurrentWord := CurrentWord . A_LoopField
				CurrentWordPixels += Width
			}
			
			PixelsTyped += Width
			
		}
	}
	
	StartIndex += 1
}

if (not BookEnded) {

	if (not PasteText) {
		Loop, Parse, CurrentWord
		{
			Send, %A_LoopField%
		}
	}
	else {
		clipboard := clipboard . CurrentWord
		Sleep, %WaitVal%
		Send, ^v
		Sleep, %WaitVal% ;############################ AUTOHOTKEY NEEDS TO WAIT A LITTLE BIT TO COMPLETELY PASTE
		clipboard := ""
	}

	clipboard := clipboardMemory
	
	CurrentWord := "" ;Reset everything; this makes way for a completely new book ############# THIS SHOULD CHANGE IF CURRENT BOOK PROGRESS IS SAVED
	CurrentWordPixels := 0
	PixelsTyped := 0
	LinesTyped := 0
	PagesTyped := 0
	
	UpdateValues(PixelsTyped, LinesTyped, PagesTyped, 100, MAX_PIXELS_PER_LINE, TimedPasted)
	
	StartIndex := 1 ;Only reverts if the full text was typed
	WordStartIndex := 1
}
else { ;Keep track of the last word, but erase everything else

	clipboard := clipboardMemory

	PixelsTyped := 0
	LinesTyped := 0
	PagesTyped := 0
	
	PercentageComplete := Floor(((WordStartIndex - 1) / StrLen(InputFile)) * 100) ;Not ALWAYS 100% if book ended
	if (PercentTyped = 100) { ;Book did end, BUT the full text was typed
		StartIndex := 1
		WordStartIndex := 1
	}
	
	UpdateValues(PixelsTyped, LinesTyped, PagesTyped, PercentageComplete, MAX_PIXELS_PER_LINE, TimesPasted)
}
SendMode Input
return



#IfWinExist BookTyper - Active
^+n:: ;Clear all pages in a book starting from page 1; useful for testing
Loop, %MAX_PAGES%
{
	Send, ^a
	Send, {Backspace}
	Send, {PgDn}
}
return