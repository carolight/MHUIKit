--[[

Example of using TableView in MHUIKit
Currently only text can be displayed in the table.

The data source should be set using tableView:setData() providing an NSArray as the argument.
A convenience function luaTableToArray() is provided to convert a Lua table to an NSArray.

Two events should be implemented:
	cellForRowAtIndexPath
	didSelectRowAtIndexPath

cellForRowAtIndexPath takes place when displaying the cells of the table
didSelectRowAtIndexPath takes place when a user selects a row

functions available:
	setData()
	setPosition()
	setSize()
	setCellText()

]]

require "ui"

local newTable = {"dog", "cat", "bird", "zebra", "finch", "antelope", "giraffe", 
	"lion", "tiger", "aardvark", "pelican", "donkey", "cow", "pig", "mouse", "snake",
	"mosquito", "elephant", "quail", "whale" }

--convert lua table to an NSArray
local holdArray = luaTableToArray(newTable)

local tableView = TableView.new("Plain")

tableView:setPosition(30,20)
tableView:setSize(250, 300)

--set the NSArray as the datasource for the table
tableView:setData(holdArray)

--takes place when user selects a row
function onDidSelectRowAtIndexPath(event)
	print("Selected:", newTable[event.Row+1])
end

tableView:addEventListener("didSelectRowAtIndexPath", onDidSelectRowAtIndexPath)

--takes place when displaying each table cell
function onCellForRowAtIndexPath(event)
	tableView:setCellText(newTable[event.Row+1])
end

tableView:addEventListener("cellForRowAtIndexPath", onCellForRowAtIndexPath)

addToRootView(tableView)
