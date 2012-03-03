require "ui"

local function showItem(event)

	-- listener event
	print("\nEvent Selected Item: " .. event.item) 

	-- explicit  calls
	print("\nRow Count: " .. pickerView:getRowCount());
	print("Selected Row: " .. pickerView:getPickedRow());
	print("Selected Item: " .. pickerView:getPickedItem());

	
end

pickerView = PickerView.new({"one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"})
pickerView:addEventListener("onPickerRows", showItem)

local row = 5

print("\nSet Row: " .. row)
pickerView:setRow(row)
pickerView:setPosition(0, 20)
addToRootView(pickerView)
