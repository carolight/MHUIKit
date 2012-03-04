require "ui"

hideStatusBar(false)
useScrollView=true
--********** Create a scrollView ************

if useScrollView==true then
	scrollView = ScrollView.new(0, 0, 320, 460, 320, 960)
	addToRootView(scrollView)

	function onScrollViewClick(event)
		local t = event:getTarget()
		print("onScrollViewClick    event type: "..event.Type.."   message: "..event.message.."   target: "..t)

	end

	scrollView:addEventListener("onScrollViewClick", onScrollViewClick)
end

--********** Create a text field ************

local textfield2 = TextField2.new("My text2 field")
textfield2:setPosition(10, 80)
textfield2:setText("Hello giderans2!")
textfield2:setSize(150,25)
if useScrollView==true then
	scrollView:add(textfield2)
else
	addToRootView(textfield2)
end

local textfield4 = TextField2.new("My text2 field")
textfield4:setPosition(10, 125)
textfield4:setText("Hello giderans2!")
textfield4:setSize(150,25)
if useScrollView==true then
	scrollView:add(textfield4)
else
	addToRootView(textfield4)
end

--********** Create a button ************
local button = Button.new()

button:setPosition(30, 210)
button:setSize(130, 30)

button:setTitle("Random number")
button:setTitleColor(255,0,0)
--button:setBGColor(1,0,1)
button:setFont("Verdana",12)

if useScrollView==true then
	scrollView:add(button)
else
	addToRootView(button)
end
--button:setBGImage("images/btnBig.png")
--button:setImage("images/btnBigH.png")
--********** Create a button ************
local btnShowAlert = Button.new()

btnShowAlert:setPosition(170, 210)
btnShowAlert:setSize(120, 30)

btnShowAlert:setTitle("Show Alert")

if useScrollView==true then
	scrollView:add(btnShowAlert)
else
	addToRootView(btnShowAlert)
end

--********** Create a slider ************
local slider = Slider.new(0,100)
slider:setPosition(80, 40)
slider:setSize(200,30)
slider:setValue(10)
--slider:setThumbImage("thumb.png")
if useScrollView==true then

	scrollView:add(slider)
else
	addToRootView(slider)
end

--********** Create a switch ************
local switch = Switch.new()
switch:setState(false)
switch:setPosition(180, 80)
if useScrollView==true then
	scrollView:add(switch)
else
	addToRootView(switch)
end

--********** Create a label ************
local label = Label.new()


label:setPosition(10, 150)
label:setSize(300, 30)

label:setText("This is a label")
label:setTextColor(1,0,0)
label:setBGColor(1,1,0)
if useScrollView==true then
	scrollView:add(label)
else
	addToRootView(label)
end
local show = false
--********** Create a alert view ************

alertView = AlertView.new("A simple alert view :-)", "Up to 5 button!!!", "Button1")
alertView:addButton("Button2")
alertView:addButton("Button3")
alertView:addButton("Button4")
alertView:addButton("Button5")

alertView:addEventListener("complete", function(event) 
    label:setText("AlertButton #"..event.buttonIndex.." was pressed! ("..event.caption..")") 
end)

function button:onClick(event)
	label:setText("The random number is: "..math.random(255))
	if show == true then
		show = false
	else
		show = true
	end
	hideStatusBar(show)
end


function switch:onClick(event)
	local state = ""
	local t = event:getTarget()
	if t:getState() == true then
		state = "ON"
	else
		state = "OFF"
	end
	label:setText ("switch is "..state)
    --print( "\nMemUsage: " .. collectgarbage("count") )
end

function btnShowAlert:onClick(event)
	--if event.target == btnShowAlert then print ("xxxxx") end
	--print (event.target)
	label:setText ("btnShowAlert clicked ("..event.message..")  "..event.caption)

	alertView:show()
end

function onClick(event)
	label:setText(event.caption.." clicked")

	alertView:show()
end


slider:addEventListener("onSliderChange", function(event) 
   local sl = event:getTarget()
   label:setText("Slider="..sl:getValue())
end)

button:addEventListener("onButtonClick",button.onClick,button)

switch:addEventListener("onSwitchClick",switch.onClick,switch)
btnShowAlert:addEventListener("onButtonClick",onClick)

textfield2:addEventListener("onTextFieldEdit", function(event) 
    label:setText("TextField2 changed->"..event.text) 
end)

textfield4:addEventListener("onTextFieldEdit", function(event) 
    label:setText("TextField4 changed->"..event.text)
end)

textfield2:addEventListener("onTextFieldReturn", function(event) 
    label:setText("TextField2 return->"..event.text)
end)

textfield4:addEventListener("onTextFieldReturn", function(event) 
    label:setText("TextField4 return->"..event.text)
end)

--********** Create a WebView ************
local webview = WebView.new("http://www.giderosmobile.com")

function onWebViewNavigation(event)
	print("onWebViewNavigation")
	print("event type: "..event.Type.."   url: "..event.Url)
	label:setText(event.Url)
end
if useScrollView==true then
	scrollView:add(webview)
else
	addToRootView(webview)
end
webview:addEventListener("onWebViewNavigation", onWebViewNavigation)


webview:setPosition(10,270)
webview:setSize(300,400)
--webview:loadLocalFile("images/Icon777.png")


--********** Create a Toolbar ************
local toolbar = Toolbar.new()
toolbar:addTextButton("text")
toolbar:addButton()
addToRootView(toolbar)

--********** Create a label for the toolbar ************
local tblabel = Label.new()
tblabel:setText("Random number")
tblabel:setSize(90, 30)
toolbar:add(tblabel)

function toolbar:onClick(event)
	print("tag "..event.tag)
end

toolbar:addEventListener("onToolbarClick",toolbar.onClick,toolbar)
stage:addEventListener(Event.ENTER_FRAME, function(event)
	collectgarbage()
	end)
