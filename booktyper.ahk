﻿#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input
SetWorkingDir %A_ScriptDir%  ;Ensures a consistent starting directory.
FileEncoding, UTF-8


FilePath := "" ;Represents the text file to be read
Version := "java" ;Represents the version to work with; ranges from java to bedrock; automatically java
CustomMode := false ;Automatically loads in "default" mode
MAX_PIXELS_PER_LINE := 114
MAX_LINES := 14
MAX_PAGES := 100 ;100 pages per book in Java Edition
InputFile := "" ;Represents the text the program is iterating through

FillLines := false ;If set to true, the current word will be broken between lines/pages instead of saved
PasteText := true ;If set to false, the letters will be typed one by one
NextBookGroup := 1
NextPageGroup := 0
NextLineGroup := 0
NextSpaceGroup := 0
NextCharGroup := 0

FileReady := true
TextReady := false
FileActivated := false ;Whether the hotkey was previously activated, with the same file
TextActivated := false ;If file activated is true, this should be false, and vice versa

;Represents the init variables a user is able to change in the settings GUI

;Array Value 1: Location of variable in settings.ini
;Array Value 2: Default variable in "bedrock" edition
;Array Value 3: Default variable in "java" edition

;Reserved location name "REF" means the GUI variable is directly linked to another variable, listed next

fluidvars := {"MAX_LINES": ["pagelines", 14, 14]
			, "MAX_PAGES": ["bookpages", 50, 100]
			, "FillLines": ["filllines", 0, 0]
			, "PasteText": ["pastetext", 1, 1]
			, "NextBookGroup": ["nbook", 1, 1]
			, "NextPageGroup": ["npage", 0, 0]
			, "NextLineGroup": ["nline", 0, 0]
			, "NextSpaceGroup": ["nspace", 0, 0]
			, "NextCharGroup": ["nchar", 0, 0]
			, "MAX_LINESData": ["REF", "MAX_LINES"]
			, "MAX_PAGESData": ["REF", "MAX_PAGES"]}

;ini file is divided up into three sections: "file," which stores the filename and version, and "java" and
;"bedrock," which store their own fluidvars



CustomIni(ByRef fluidvars, Version) { ;Only called when load in custom settings is pressed

	For Option, Presets in fluidvars
	{
		if (Presets[1] != "REF") {
			IniLoc := Presets[1]
			IniRead, %Option%, settings.ini, %Version%, %IniLoc% ;The ini file saves options for both java and bedrock
			%Option% += 0
		}
	}
}

StartWrite(FilePath, Version) { ;Should only be called when hotkey is started; "shadow" save
	
	if (FilePath = "Select a file..." or FilePath = "") {
		IniWrite, "", settings.ini, file, filename
	}
	else {
		IniWrite, %FilePath%, settings.ini, file, filename
	}
	IniWrite, %Version%, settings.ini, file, version
}

CustomWrite(fluidvars, Version) { ;Should only be called when save is pressed on settings

	For Option, Presets in fluidvars
	{
		if (Presets[1] != "REF") {
			OptionValue := %Option%
			IniLoc := Presets[1]
			IniWrite, %OptionValue%, settings.ini, %Version%, %IniLoc%
		}
	}
}



IniRead, FilePath, settings.ini, file, filename
if (FilePath = "ERROR" or FilePath = "") {
	FilePath := "Select a file..."
	FileReady := false
}

IniRead, Version, settings.ini, file, version
if (Version = "bedrock") {
	MAX_PAGES := 50
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
TimesPasted := 0 ;Keeps track of the "iterations"
Steps := 0 ;Keeps track of how many times the paste button has been hit while the entire text has not been pasted
PastStack := Array() ;Represents the "past" pastes; allows a user to go back a step
PastStack.Push([CurrentWord, CurrentWordPixels, StartIndex, WordStartIndex, 0, PixelsTyped, LinesTyped, PagesTyped])
FutureStack := Array() ;Stores pastes as user goes back steps; allows them to go forward once again



PresetsWidth := "W360"
PresetsHeight := "H300"

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
Gui, Presets:Add, Radio, X70 Y230 vVersionsGroup gJavaCMD, Java Edition
Gui, Presets:Add, Radio, X200 Y230 gBedrockCMD, Bedrock Edition
;Gui, Presets:Add, CheckBox, X240 Y230 gCustomizeCMD, Custom Settings



CustomizeWidth := "W560"
CustomizeHeight := "H300"
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
Gui, Customize:Add, Text, X220 Y20, When done pasting, go to:
Gui, Customize:Add, Radio, X220 Y50 vNextBookGroup gUpdateCMD, Next Book ;This solution sacrifices streamlining to fit nicely into fluidvars
Gui, Customize:Add, Radio, X220 Y75 vNextPageGroup gUpdateCMD, Next Page
Gui, Customize:Add, Radio, X220 Y100 vNextLineGroup gUpdateCMD, Next Line
Gui, Customize:Add, Radio, X220 Y125 vNextSpaceGroup gUpdateCMD, Next Space
Gui, Customize:Add, Radio, X220 Y150 vNextCharGroup gUpdateCMD, Next Character
GuiControl, Customize:, NextBookGroup, %NextBookGroup%
GuiControl, Customize:, NextPageGroup, %NextPageGroup%
GuiControl, Customize:, NextLineGroup, %NextLineGroup%
GuiControl, Customize:, NextSpaceGroup, %NextSpaceGroup%
GuiControl, Customize:, NextCharGroup, %NextCharGroup%
Gui, Customize:Add, CheckBox, X20 Y170 vFillLines gUpdateCMD, Always fill lines
GuiControl, Customize:, FillLines, %FillLines%
Gui, Customize:Add, CheckBox, X20 Y195 vPasteText gUpdateCMD, Copy text to clipboard and paste (disabling makes it slower)
GuiControl, Customize:, PasteText, %PasteText%
Gui, Customize:Add, Button, X20 Y255 vCustReturn gCustReturnCMD, Return
Gui, Customize:Add, Button, X80 Y255 vSaveButton gSaveCMD, Save
GuiControl, Customize:Disable, SaveButton
Gui, Customize:Add, Button, X133 Y255 vLoadButton gLoadCMD, Load
Gui, Customize:Add, Button, X185 Y255 vDefaultButton gDefaultCMD, Revert to Defaults
GuiControl, Customize:Disable, DefaultButton



PasterWidth := "W450"
PasterHeight := "H170"

Gui, Paster:New, , BookTyper - Active
Gui, Paster:Add, Text, X110 Y20, In Minecraft, paste text using CTRL + Shift + B.
Gui, Paster:Add, Text, X25 Y40, To clear all the text from a book, go to the starting page and press CTRL + Shift + N.
Gui, Paster:Add, Progress, X20 Y67 W370 H20 cBlue BackgroundCFCFCF vTypingCompletion, 0
Gui, Paster:Add, Edit, X400 Y67 W35 H20 vCompletionText, 0`%
GuiControl, Paster:Disable, CompletionText
Gui, Paster:Add, Text, X20 Y100, Current Page:
Gui, Paster:Add, Edit, X90 Y98 W23 vCurrentPage, 1 ;Program always starts typing at page 1, line 1
GuiControl, Paster:Disable, CurrentPage
Gui, Paster:Add, Text, X120 Y100, Current Line:
Gui, Paster:Add, Edit, X185 Y98 W23 vCurrentLine, 1
GuiControl, Paster:Disable, CurrentLine
Gui, Paster:Add, Text, X214 Y100, Pixels Left (on line):
Gui, Paster:Add, Edit, X312 Y98 W30 vCurrentPixels, %MAX_PIXELS_PER_LINE% ;Should be 114 unless the user changes it
GuiControl, Paster:Disable, CurrentPixels
Gui, Paster:Add, Text, X350 Y100, Iterations:
Gui, Paster:Add, Edit, X400 Y98 W23 vTimesPasted, 0
GuiControl, Paster:Disable, TimesPasted
Gui, Paster:Add, Text, X370 Y135, Step:
Gui, Paster:Add, Edit, X400 Y133 W23 vSteps, 0
GuiControl, Paster:Disable, Steps
Gui, Paster:Add, Button, X200 Y130 vStepBack gStepBackCMD, Step Back
GuiControl, Paster:Disable, StepBack ;Nothing has been pasted yet
Gui, Paster:Add, Button, X280 Y130 vStepForward gStepForwardCMD, Step Forward
GuiControl, Paster:Disable, StepForward
Gui, Paster:Add, Button, X20 Y130 vActiveReturn gActiveReturnCMD, Return
Gui, Paster:Add, Button, X82 Y130 vReset gResetCMD, Reset
GuiControl, Paster:Disable, Reset ;Nothing to reset at the beginning


UpdateValues(PixelsTyped, LinesTyped, PagesTyped, PercentageComplete, MAX_PIXELS_PER_LINE, ByRef TimesPasted, ByRef Steps) { ;Called once hotkey is finished typing

	CurrentPage := (1 + PagesTyped)
	CurrentLine := (1 + LinesTyped)
	CurrentPixels := (MAX_PIXELS_PER_LINE - PixelsTyped)
	
	GuiControl, Paster:, CurrentPage, %CurrentPage%
	GuiControl, Paster:, CurrentLine, %CurrentLine%
	GuiControl, Paster:, CurrentPixels, %CurrentPixels%
	
	GuiControl, Paster:, TypingCompletion, %PercentageComplete%
	GuiControl, Paster:, CompletionText, %PercentageComplete%`%
	
	if (PercentageComplete = 100)
		TimesPasted += 1
	GuiControl, Paster:, TimesPasted, %TimesPasted%
	Steps += 1
	GuiControl, Paster:, Steps, %Steps%
}



if (Version = "java") {
	GuiControl, Presets:, Java Edition, 1
} else {
	GuiControl, Presets:, Bedrock Edition, 1
}

if (not FileReady) {
	GuiControl, Presets:Disable, StartFileButton
}

if (not TextReady) {
	GuiControl, Presets:Disable, StartTextButton
}

Gui, Presets:Show, %PresetsWidth% %PresetsHeight% Center
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

	if (FileActivated) {
		FileActivated := false ;Doesn't check whether the file is the same, as it could have been modified
		gosub ResetCMD
	}

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


StartButtonCMD: ;Begin the hotkey
Gui, Presets:Submit, NoHide
Gui, Customize:Submit, NoHide ;Use current customized settings, even if they weren't saved

if (TextActivated) { ;InputFile is not empty; has the previously entered text
	if (InputFile != EnterField) {
		TextActivated := false
		gosub ResetCMD
	}
}

if (A_GuiControl = "StartFileButton" and (not FileActivated)) { ;Read from file selected
	
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

	if (TextActivated) { ;Switching from pasting the text field to pasting the file; assumed to be of different content
		TextActivated := false
		gosub ResetCMD
	}

	FileActivated := true
}
else if (A_GuiControl = "StartTextButton" and (not TextActivated)) { ;Read from text entered
	InputFile := EnterField

	if (FileActivated) {
		FileActivated := false
		gosub ResetCMD
	}

	TextActivated := true
}

StartWrite(FilePath, Version)
Gui, Presets:Hide
Gui, Paster:Show, %PasterWidth% %PasterHeight% Center
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

	if (CustomMode) {
		GuiControl, Customize:Disable, DefaultButton
		CustomMode := false
	}
}
return


BedrockCMD: ;********** Called when Bedrock Edition radio button is clicked
if (Version != "bedrock") { ;************FOR BEDROCK PASTING, PRESS ESC, RIGHT ARROW KEY, THEN EITHER ENTER OR KEEP TYPING
	
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
	
	if (CustomMode) {
		GuiControl, Customize:Disable, DefaultButton
		CustomMode := false
	}
}
return


SettingsButtonCMD: ;Switch to settings window
Gui, Presets:Hide
Gui, Customize:Show, %CustomizeWidth% %CustomizeHeight% Center
return



SaveCMD:
Gui, Customize:Submit, NoHide
CustomWrite(fluidvars, Version)
GuiControl, Customize:Disable, SaveButton
ChangesMade := false
return


LoadCMD: ;********** Called when load button is clicked
CustomIni(fluidvars, Version)
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
CustomMode := true
GuiControl, Customize:Enable, DefaultButton

if (ChangesMade) {
	GuiControl, Customize:Disable, SaveButton
	ChangesMade := false
}
return


DefaultCMD: ;********** Called when revert to defaults button is clicked
if (Version = "java") {
	Version := ""
	gosub JavaCMD ;Cheaty way to revert variables
}
else {
	Version := ""
	gosub BedrockCMD
}
;GuiControl, Customize:Disable, DefaultButton ;Should have already been called by either java or bedrock cmd
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

if (not CustomMode) {
	CustomMode := true
	GuiControl, Customize:Enable, DefaultButton
}
return


CustReturnCMD: ;Return to general window from settings
Gui, Customize:Hide
Gui, Presets:Show, %PresetsWidth% %PresetsHeight% Center
return



ActiveReturnCMD: ;Return to general window from active mode; don't erase everything just yet
Gui, Paster:Hide
Gui, Presets:Show, %PresetsWidth% %PresetsHeight% Center
return


ResetCMD: ;Erase all "progress" made with the current file or text field; should only be called when either is made different by the user
CurrentWord := ""
CurrentWordPixels := 0
PixelsTyped := 0
LinesTyped := 0
PagesTyped := 0
StartIndex := 1
WordStartIndex := 1
TimesPasted := 0
Steps := 0
PastStack := Array()
PastStack.Push([CurrentWord, CurrentWordPixels, StartIndex, WordStartIndex, 0, PixelsTyped, LinesTyped, PagesTyped])
FutureStack := Array()
UpdateValues(0, 0, 0, 0, MAX_PIXELS_PER_LINE, 0, -1)
GuiControl, Paster:Disable, Reset ;Disable if pressed or if everything has already been reset
GuiControl, Paster:Disable, StepBack ;Should not be available if there is no "memory"
GuiControl, Paster:Disable, StepForward
return


;([CurrentWord, CurrentWordPixels, StartIndex, WordStartIndex, 100, PixelsTyped, LinesTyped, PagesTyped])
StepBackCMD:
;Past stack contains the present situation at the top, but we want to go back from that
FutureStack.Push(PastStack.Pop()) ;This subroutine should not be callable if past stack is only of length 1

PData := PastStack[PastStack.Length()]
CurrentWord := PData[1]
CurrentWordPixels := PData[2]
StartIndex := PData[3]
WordStartIndex := PData[4]
PercentageComplete := PData[5]
PixelsTyped := PData[6]
LinesTyped := PData[7]
PagesTyped := PData[8]

if (PercentageComplete = 100)
	TimesPasted -= 1
Steps -= 2
UpdateValues(PixelsTyped, LinesTyped, PagesTyped, PercentageComplete, MAX_PIXELS_PER_LINE, TimesPasted, Steps)
if (PastStack.Length() = 1)
	GuiControl, Paster:Disable, StepBack
GuiControl, Paster:Enable, StepForward
return


StepForwardCMD:
;Future stack always contains the future we want at the top
FData := FutureStack.Pop() ;Again, this routine should not be callable if future stack is empty

CurrentWord := FData[1]
CurrentWordPixels := FData[2]
StartIndex := FData[3]
WordStartIndex := FData[4]
PercentageComplete := FData[5]
PixelsTyped := FData[6]
LinesTyped := FData[7]
PagesTyped := FData[8]

if (PercentageComplete = 100)
	TimesPasted -= 1
UpdateValues(PixelsTyped, LinesTyped, PagesTyped, PercentageComplete, MAX_PIXELS_PER_LINE, TimesPasted, Steps)
PastStack.Push(FData)
GuiControl, Paster:Enable, StepBack
if (FutureStack.Length() = 0)
	GuiControl, Paster:Disable, StepForward
return



PageFlip(Version, PagesTyped) { ;Java and Bedrock differ in the keys they use to flip pages
;As well as this, Bedrock has a hard coded limit of max 244 (?) characters per page

	if (Version = "java") ;Simpler page turn
		Send, {PgDn}
	else { ;Bedrock turning
		SendMode Event ;Sending is more "reliable" this way
		SetKeyDelay, 20
		Send, {Esc 1}
		Send, {Right 1}
		if (Mod(PagesTyped, 2) = 1) { ;On an even numbered page; "flip" the two pages
			SendInput, {Enter} ;*************THIS IS REPEATING OVER AND OVER WHEN IT SHOULD BE PRESSED ONCE
			Send, {Left 2} ;Move to the previous of the next two pages
		}
		;MsgBox, %PagesTyped%
		;Sleep, 5000
		SendMode Input
	}
}


#IfWinExist BookTyper - Active
^+b::

BookEnded := false ;When the book ends, do not type the current word out
clipboardMemory := clipboard ;Remember what was placed in the clipboard
clipboard := "" ;Utilized in pasting mode

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
		SendInput, %clipboard%
		clipboard := ""
	}
	WordStartIndex := StartIndex + 1
}


TextSendPageEnd(CurrentWord, PasteText, ByRef WordStartIndex, StartIndex, Version, PagesTyped) {
	if (not PasteText) {
		Loop, Parse, CurrentWord ;Clear text lines
		{
			Send, %A_LoopField%
		}
		PageFlip(Version, PagesTyped)
	}
	else {
		clipboard := clipboard . CurrentWord
		SendInput, %clipboard% ;Paste
		PageFlip(Version, PagesTyped)
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



if (NextLineGroup)
	ReadText := SubStr(InputFile, StartIndex) . "`n"
else if (NextSpaceGroup)
	ReadText := SubStr(InputFile, StartIndex) . " "
else
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
								SendInput, %clipboard%
								clipboard := ""
							}

							CurrentWord := CurrentWord . A_LoopField
						}
					}
					
					BookEnded = true ;Resets the current word pixels, pixels typed, and lines typed at the end; doesn't have to do it here
					StartIndex += 1
					Break
				}
				else { ;Book unfinished, next page
					
					if (CurrentWordPixels = PixelsTyped or (CurrentWordPixels + Width) > MAX_PIXELS_PER_LINE or FillLines) {
						
						TextSendPageEnd(CurrentWord, PasteText, WordStartIndex, StartIndex, Version, PagesTyped)
						
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
						
							TextSendPageEnd(CurrentWord, PasteText, WordStartIndex, StartIndex, Version, PagesTyped)
							
							CurrentWord := ""
							CurrentWordPixels := 0
							PixelsTyped := 0
							LinesTyped := 0
						}
						else {
							
							if (PasteText) {
								SendInput, %clipboard%
								PageFlip(Version, PagesTyped)
								clipboard := ""
							}
							else
								PageFlip(Version, PagesTyped)
							
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
						else
							clipboard := clipboard . "`n"
						
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

if (PastStack.Length() != 0) {
	if (PastStack[PastStack.Length()][5] = 100) { ;At this point, steps should have been set to 0, and are about to be set to 1
		PrevPData := PastStack.Pop()
		PastStack := Array() ;The size of past stack should correspond with the value of steps
		PastStack.Push(PrevPData)
		Steps := 0
	}
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
		SendInput, %clipboard%
		clipboard := ""
	}

	clipboard := clipboardMemory
	
	CurrentWord := ""

	if (not (NextCharGroup and CurrentWordPixels = PixelsTyped))
		CurrentWordPixels := 0 ;If the user keeps pasting, the script will allow word splices, even if they are split between "pastes"

	;Only one of the "group" variables are true at a time
	if (NextBookGroup or (NextPageGroup and (PagesTyped + 1 = MAX_PAGES))) { ;Either go to the next book, or out of pages
		PixelsTyped := 0
		LinesTyped := 0
		PagesTyped := 0
	} else if (NextPageGroup) { ;Enough pages to "flip"
		PageFlip(Version, PagesTyped)
		PixelsTyped := 0
		LinesTyped := 0
		PagesTyped += 1
	} ;else if (NextLineGroup or NextSpaceGroup or NextCharGroup) ;Nothing needs to be done
	
	UpdateValues(PixelsTyped, LinesTyped, PagesTyped, 100, MAX_PIXELS_PER_LINE, TimesPasted, Steps)
	GuiControl, Paster:Enable, Reset

	StartIndex := 1 ;Only reverts if the full text was typed
	WordStartIndex := 1

	;The script's "memory"
	PastStack.Push([CurrentWord, CurrentWordPixels, StartIndex, WordStartIndex, 100, PixelsTyped, LinesTyped, PagesTyped])
	FutureStack := Array() ;Always erase after a paste
	GuiControl, Paster:Enable, StepBack ;When past stack is not a length of 1, this should be available
	GuiControl, Paster:Disable, StepForward ;When future stack is empty, this should not be available
}
else { ;Keep track of the last word, but erase everything else

	clipboard := clipboardMemory

	PixelsTyped := 0
	LinesTyped := 0
	PagesTyped := 0
	
	PercentageComplete := Floor(((WordStartIndex - 1) / StrLen(InputFile)) * 100) ;Not ALWAYS 100% if book ended
	if (PercentageComplete = 100) { ;Book did end, BUT the full text was typed
		StartIndex := 1
		WordStartIndex := 1
	}
	
	UpdateValues(PixelsTyped, LinesTyped, PagesTyped, PercentageComplete, MAX_PIXELS_PER_LINE, TimesPasted, Steps)
	GuiControl, Paster:Enable, Reset

	PastStack.Push([CurrentWord, CurrentWordPixels, StartIndex, WordStartIndex, PercentageComplete, PixelsTyped, LinesTyped, PagesTyped])
	FutureStack := Array()
	GuiControl, Paster:Enable, StepBack
	GuiControl, Paster:Disable, StepForward
}
;Send, {LControl up}{RControl up} ;Prevents weird control holding bug
SoundPlay, *-1
return



#IfWinExist BookTyper - Active
^+n:: ;Clear all pages in a book starting from page 1; useful for testing
Loop, %MAX_PAGES%
{
	if (Version = "bedrock") {
		Send, {Enter} ;Needed to put the cursor on the page
		SendEvent, {Ctrl down}a{Ctrl up}
	}
	else
		Send, ^a
	Send, {Delete}
	PageFlip(Version, (A_Index - 1))
}
return