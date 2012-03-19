//Changes 18th March 2012 - Caroline Begbie
//added pragma marks
//added convenience function luaTableToArray 
//added UITableView (WIP)

#include "gideros.h"
#include <set>

std::set<UIView*> topUIViews;

static const char KEY_OBJECTS = ' ';
static const char KEY_ROOTOBJECTS = ' ';

// create a weak table in LUA_REGISTRYINDEX that can be accessed with the address of KEY_OBJECTS
static void createObjectsTable(lua_State* L)
{
	lua_pushlightuserdata(L, (void *)&KEY_OBJECTS);
	lua_newtable(L);                  // create a table
	lua_pushliteral(L, "v");
	lua_setfield(L, -2, "__mode");    // set as weak-value table
	lua_pushvalue(L, -1);             // duplicate table
	lua_setmetatable(L, -2);          // set itself as metatable
	lua_rawset(L, LUA_REGISTRYINDEX);	
}

static void createRootObjectsTable(lua_State* L)
{
	lua_pushlightuserdata(L, (void *)&KEY_ROOTOBJECTS);
	lua_newtable(L);	
	lua_rawset(L, LUA_REGISTRYINDEX);	
}

static void setObject(lua_State* L, void* ptr)
{
	lua_pushlightuserdata(L, (void *)&KEY_OBJECTS);
	lua_rawget(L, LUA_REGISTRYINDEX);
	lua_pushlightuserdata(L, ptr);
	lua_pushvalue(L, -3);
	lua_rawset(L, -3);
	lua_pop(L, 1);
}

static void getObject(lua_State* L, void* ptr)
{
	lua_pushlightuserdata(L, (void *)&KEY_OBJECTS);
	lua_rawget(L, LUA_REGISTRYINDEX);
	lua_pushlightuserdata(L, ptr);
	lua_rawget(L, -2);
	lua_remove(L, -2);
}


//------g_pathForFile("|D|myImage.png")---------
/*const char* g_pathForFile(const char* filename)
{
    const char* pathForFile(const char* filename);
    return pathForFile(filename);
}
*/
//----------------------------------------------------------------------------------------------
@interface SelectorToEvent : NSObject
{
	GReferenced* target;
	lua_State* L;
	NSString* type;
}

@property (nonatomic, assign) GReferenced* target;
@property (nonatomic, assign) lua_State* L;
@property (nonatomic, copy) NSString* type;

-(void)event:(id)sender;

@end


@implementation SelectorToEvent

@synthesize target;
@synthesize L;
@synthesize type;

-(void)event:(id)sender
{	
	NSLog(@"SelectorToEvent called");
	NSLog(@"%@", type);
	getObject(L, target);

	UIButton* myButton = (UIButton*)sender;
	UISwitch* mySwitch = (UISwitch*)sender;
	UISlider* mySlider = (UISlider*)sender;
	UITextField* myTextField = (UITextField*)sender;
	UIBarButtonItem* myTBButton = (UIBarButtonItem*)sender;
	
	if (!lua_isnil(L, -1))
	{
		NSLog(@"dispatch an event");
		lua_getfield(L, -1, "dispatchEvent");
		
		lua_pushvalue(L, -2);
		
		lua_getglobal(L, "Event");
		lua_getfield(L, -1, "new");
		lua_remove(L, -2);
		
		lua_pushstring(L, [type UTF8String]);
		lua_call(L, 1, 1);
	
		if( [type isEqualToString:@"onToolbarClick"])
		{
			NSString *caption;
			
			
			switch(myTBButton.style)
			{
				case UIBarButtonSystemItemDone:
					caption = @"_tbbSYSDone";
					break;
				default:
					caption = myTBButton.title;
					break;
			}
			
			lua_pushstring(L, [caption UTF8String]);
			
			lua_setfield(L, -2, "caption");
			lua_pushinteger(L, myTBButton.tag);
			lua_setfield(L, -2, "tag");
		}
		
		if( [type isEqualToString:@"onTextFieldEdit"])
		{
			NSString *text = myTextField.text;
			lua_pushstring(L, [text UTF8String]);
			lua_setfield(L, -2, "text");
		}
		
		if( [type isEqualToString:@"onSliderChange"])
		{
			lua_pushinteger(L, mySlider.value);
			lua_setfield(L, -2, "value");
		}
		
		if( [type isEqualToString:@"onButtonClick"])
		{
			//lua_pushinteger(L, myButton.tag);
			NSString *caption = myButton.titleLabel.text;
			lua_pushstring(L, [caption UTF8String]);
			
			lua_setfield(L, -2, "caption");
		}
		
		if( [type isEqualToString:@"onSwitchClick"])
		{
			//lua_pushinteger(L, mySwitch.on);
			lua_pushboolean(L, mySwitch.on);
			lua_setfield(L, -2, "state");
		}
		
		lua_pushstring(L, [type UTF8String]);
		lua_setfield(L, -2, "message");

		if (lua_pcall(L, 2, 0, 0) != 0)
		{
			g_error(L, lua_tostring(L, -1));
			return;
		}
	}
	
	lua_pop(L, 1);
}

-(void)dealloc
{
	[type release];
	[super dealloc];
}

@end

//----------------------------------------------------------------------------------------------
#pragma mark ---- UIView ----

class View : public GEventDispatcherProxy
{
public:
	View(lua_State* L)
	{
		selectorToEvent = [[SelectorToEvent alloc] init];
		selectorToEvent.target = this;
		selectorToEvent.L = L;
	}
		
	virtual ~View()
	{
		[uiView release];
		[selectorToEvent release];
	}
	
	virtual void create()
	{
		uiView = [[UIView alloc] init];
	}

	void addView(View* childView)
	{
		[uiView addSubview:childView->uiView];
	}
	
	void removeFromParent()
	{
		[uiView removeFromSuperview];
	}
	
	void setPosition(int x, int y)
	{
		CGRect frame = uiView.frame;
		frame.origin.x = x;
		frame.origin.y = y;
		uiView.frame = frame;	
	}
	
	void setSize(int width, int height)
	{
		CGRect frame = uiView.frame;
		frame.size.width = width;
		frame.size.height = height;
		uiView.frame = frame;			
	}
	
	UIView* uiView;
	SelectorToEvent* selectorToEvent;
};

//----------------------------------------------------------------------------------------------
class ViewBinder
{
public:
	ViewBinder(lua_State* L);
	
private:
	static int create(lua_State* L);
	static int destruct(lua_State* L);
	
	static int addView(lua_State* L);
	static int removeFromParent(lua_State* L);
	static int setPosition(lua_State* L);
	static int setSize(lua_State* L);
};

ViewBinder::ViewBinder(lua_State* L)
{
	const luaL_Reg functionlist[] = {
		//{"addView", addView},						// Note: currently we don't want to create hierarchies
		//{"removeFromParent", removeFromParent},
		{"setPosition", setPosition},
		{"setSize", setSize},
		{NULL, NULL},
	};
	
	g_createClass(L, "View", "EventDispatcher", create, destruct, functionlist);
}


int ViewBinder::create(lua_State* L)
{
	View* view = new View(L);
	view->create();
	g_pushInstance(L, "View", view->object());
	
	setObject(L, view);
	
	return 1;
}

int ViewBinder::destruct(lua_State* L)
{
	void* ptr = *(void**)lua_touserdata(L, 1);
	GReferenced* object = static_cast<GReferenced*>(ptr);
	View* view = static_cast<View*>(object->proxy());
	
	view->unref(); 
	
	return 0;
}

int ViewBinder::addView(lua_State* L)
{
	GReferenced* viewObject = static_cast<GReferenced*>(g_getInstance(L, "View", 1));
	GReferenced* childViewObject = static_cast<GReferenced*>(g_getInstance(L, "View", 2));
	
	View* view = static_cast<View*>(viewObject->proxy());
	View* childView = static_cast<View*>(childViewObject->proxy());
	
	view->addView(childView);
	
	return 0;
}

int ViewBinder::removeFromParent(lua_State* L)
{
	GReferenced* viewObject = static_cast<GReferenced*>(g_getInstance(L, "View", 1));
	View* view = static_cast<View*>(viewObject->proxy());
	
	view->removeFromParent();
	
	return 0;
}


int ViewBinder::setPosition(lua_State* L)
{
	GReferenced* viewObject = static_cast<GReferenced*>(g_getInstance(L, "View", 1));
	View* view = static_cast<View*>(viewObject->proxy());
	
	int x = luaL_checkinteger(L, 2);
	int y = luaL_checkinteger(L, 3);
	view->setPosition(x, y);
	
	return 0;
}

int ViewBinder::setSize(lua_State* L)
{
	GReferenced* viewObject = static_cast<GReferenced*>(g_getInstance(L, "View", 1));
	View* view = static_cast<View*>(viewObject->proxy());
	
	int width = luaL_checkinteger(L, 2);
	int height = luaL_checkinteger(L, 3);
	view->setSize(width, height);
	
	return 0;	
}

//----------------------------------------------------------------------------------------------
#pragma mark ---- UISwitch ----

class Switch : public View
{
public:
	Switch(lua_State* L) : View(L)
	{
		selectorToEvent.type = @"onSwitchClick";		
	}
	
	virtual ~Switch()
	{
		[(UISwitch*)uiView removeTarget:selectorToEvent action:@selector(event:) forControlEvents:UIControlEventTouchUpInside];
	}
	
	virtual void create()	
	{
		UISwitch* iswitch = [[UISwitch alloc] init];
		[iswitch setOn:true];
		[iswitch  addTarget:selectorToEvent action:@selector(event:) forControlEvents:UIControlEventTouchUpInside];
		[iswitch retain];
		
		uiView = iswitch;
		
	}
	
	void setState(bool state)
	{
		[(UISwitch*)uiView setOn:state];
	}
	
	bool getState()
	{
		UISwitch* mySwitch = (UISwitch*)uiView;
		return mySwitch.on;
	}
	
};

//----------------------------------------------------------------------------------------------
class SwitchBinder
{
public:
	SwitchBinder(lua_State* L);
	
private:
	static int create(lua_State* L);
	static int destruct(lua_State* L);
	static int setState(lua_State* L);
	static int getState(lua_State* L);
};

SwitchBinder::SwitchBinder(lua_State* L)
{
	const luaL_Reg functionlist[] = {
		{"setState", setState},
		{"getState", getState},
		{NULL, NULL},
	};
	
	g_createClass(L, "Switch", "View", create, destruct, functionlist);	
}

int SwitchBinder::create(lua_State* L)
{
	Switch* iswitch = new Switch(L);
	iswitch->create();
	
	g_pushInstance(L, "Switch", iswitch->object());
	
	setObject(L, iswitch);
	
	return 1;
}

int SwitchBinder::destruct(lua_State* L)
{
	void* ptr = *(void**)lua_touserdata(L, 1);
	GReferenced* object = static_cast<GReferenced*>(ptr);
	Switch* iswitch = static_cast<Switch*>(object->proxy());
	
	iswitch->unref(); 
	
	return 0;
}

int SwitchBinder::setState(lua_State* L)
{
	GReferenced* switchObject = static_cast<GReferenced*>(g_getInstance(L, "Switch", 1));
	Switch* iswitch = static_cast<Switch*>(switchObject->proxy());
	bool state = lua_toboolean(L, 2);
	iswitch->setState(state);
	return 0;
}

int SwitchBinder::getState(lua_State* L)
{
	GReferenced* switchObject = static_cast<GReferenced*>(g_getInstance(L, "Switch", 1));
	Switch* iswitch = static_cast<Switch*>(switchObject->proxy());
	lua_pushboolean(L, iswitch->getState());
	return 1;
}

//----------------------------------------------------------------------------------------------
#pragma mark ---- UISlider ----

class Slider : public View
{
public:
	Slider(lua_State* L) : View(L)
	{
		selectorToEvent.type = @"onSliderChange";		
	}
	
	virtual ~Slider()
	{
		[(UISlider*)uiView removeTarget:selectorToEvent action:@selector(event:) forControlEvents:UIControlEventValueChanged];
	}
	
	virtual void create(float min, float max)	
	{
		
		CGRect frame = CGRectMake(0.0, 0.0, 200.0, 10.0);
		UISlider *slider = [[UISlider alloc] initWithFrame:frame];
		[slider setBackgroundColor:[UIColor clearColor]];
		slider.minimumValue = min;
		slider.maximumValue = max;
		slider.continuous = YES;
		slider.value = (max+min)/2.0;
		
		//[iswitch setOn:true];
		[slider  addTarget:selectorToEvent action:@selector(event:) forControlEvents:UIControlEventValueChanged];
		[slider retain];
		uiView = slider;
	}
	
	void setValue(float value)
	{
		[(UISlider*)uiView setValue:value];
	}
	
	int getValue()
	{
		UISlider* mySlider = (UISlider*)uiView;
		return mySlider.value;
	}
	
	void setThumbImage(NSString* imagefile)
	{
		//NSLog(imagefile);
		//UIImage *sliderThumb = [UIImage imageNamed:imagefile];
		UIImage *sliderThumb = [[[UIImage alloc] initWithContentsOfFile:imagefile] autorelease];
		[(UISlider*)uiView setThumbImage:sliderThumb forState:UIControlStateNormal];
		[(UISlider*)uiView setThumbImage:sliderThumb forState:UIControlStateHighlighted];
	}
	


};

//----------------------------------------------------------------------------------------------
class SliderBinder
{
public:
	SliderBinder(lua_State* L);
	
private:
	static int create(lua_State* L);
	static int destruct(lua_State* L);
	static int setValue(lua_State* L);
	static int getValue(lua_State* L);
	static int setThumbImage(lua_State* L);
};

SliderBinder::SliderBinder(lua_State* L)
{
	const luaL_Reg functionlist[] = {
		{"setValue", setValue},
		{"getValue", getValue},
		{"setThumbImage", setThumbImage},
		{NULL, NULL},
	};
	
	g_createClass(L, "Slider", "View", create, destruct, functionlist);	
}

int SliderBinder::create(lua_State* L)
{
	float min = luaL_checknumber(L, 1);
	float max = luaL_checknumber(L, 2);
	Slider* slider = new Slider(L);
	slider->create(min, max);
	
	g_pushInstance(L, "Slider", slider->object());
	
	setObject(L, slider);
	
	return 1;
}

int SliderBinder::destruct(lua_State* L)
{
	void* ptr = *(void**)lua_touserdata(L, 1);
	GReferenced* object = static_cast<GReferenced*>(ptr);
	Slider* slider = static_cast<Slider*>(object->proxy());
	
	slider->unref(); 
	
	return 0;
}

int SliderBinder::setValue(lua_State* L)
{
	GReferenced* sliderObject = static_cast<GReferenced*>(g_getInstance(L, "Slider", 1));
	Slider* slider = static_cast<Slider*>(sliderObject->proxy());
	float value = luaL_checknumber(L, 2);
	slider->setValue(value);
	return 0;
}

int SliderBinder::getValue(lua_State* L)
{
	GReferenced* sliderObject = static_cast<GReferenced*>(g_getInstance(L, "Slider", 1));
	Slider* slider = static_cast<Slider*>(sliderObject->proxy());
	lua_pushnumber(L, slider->getValue());
	return 1;
}

int SliderBinder::setThumbImage(lua_State* L)
{
	GReferenced* sliderObject = static_cast<GReferenced*>(g_getInstance(L, "Slider", 1));
	Slider* slider = static_cast<Slider*>(sliderObject->proxy());
	const char* imagename = luaL_checkstring(L, 2);
	slider->setThumbImage([NSString stringWithUTF8String:g_pathForFile(imagename)]);
	//slider->setThumbImage([NSString stringWithUTF8String:imagename]);
	return 0;
}


//----------------------------------------------------------------------------------------------
#pragma mark ---- UIToolbar ----

class Toolbar : public View
{
public:
	Toolbar(lua_State* L) : View(L)
	{
		selectorToEvent.type = @"onToolbarClick";		
	}
	
	virtual ~Toolbar()
	{
		//[(UIToolbar*)uiView removeTarget:selectorToEvent action:@selector(event:) forControlEvents:UIControlEventValueChanged];
	}
	
	virtual void create()	
	{
		//Initialize the toolbar 
		UIToolbar *toolBar = [[UIToolbar alloc] init]; toolBar.barStyle = UIBarStyleDefault;
		//Set the toolbar to fit the width of the app. 
		[toolBar sizeToFit];
		//Caclulate the height of the toolbar 
		CGFloat toolbarHeight = [toolBar frame].size.height;
		
		UIViewController* controller = g_getRootViewController();	
		UIView* rootView = controller.view;
		//Get the bounds of the parent view 
		CGRect rootViewBounds = rootView.bounds;
		
		//Get the height of the parent view. 
		CGFloat rootViewHeight = CGRectGetHeight(rootViewBounds);
		
		//Get the width of the parent view, 
		CGFloat rootViewWidth = CGRectGetWidth(rootViewBounds);
		
		//Create a rectangle for the toolbar 
		CGRect rectArea = CGRectMake(0, rootViewHeight - toolbarHeight, rootViewWidth, toolbarHeight);
		
		//Reposition and resize the receiver 
		[toolBar setFrame:rectArea];
		[toolBar retain];
		uiView = toolBar;
		
	}
	void addButton()
	{
		UIToolbar* toolBar = (UIToolbar*)uiView;
		
		UIBarButtonItem *systemItem1 = [[UIBarButtonItem alloc] 
										initWithBarButtonSystemItem:UIBarButtonSystemItemCamera
										target:selectorToEvent
                                        action:@selector(event:)];
		NSMutableArray *toolbarItems = [[NSMutableArray arrayWithArray:toolBar.items] retain];
		long c = [toolbarItems count];
		c = c+1;
		systemItem1.tag = c;
		
        [toolbarItems addObject:systemItem1];
		//[toolbarItems replaceObjectAtIndex:checkUncheckIndex withObject:barButtonItem];
		
        toolBar.items = toolbarItems;
		
	}
	
	void addTextButton(NSString* caption)
	{
		UIToolbar* toolBar = (UIToolbar*)uiView;
		UIBarButtonItem *button = [[UIBarButtonItem alloc]
								   initWithTitle:caption 
								   style:UIBarButtonItemStyleBordered 
								   target:selectorToEvent
								   action:@selector(event:)];
		NSMutableArray *toolbarItems = [[NSMutableArray arrayWithArray:toolBar.items] retain];
		long c = [toolbarItems count];
		c = c+1;
		button.tag = c;
        [toolbarItems addObject:button];
		//[toolbarItems replaceObjectAtIndex:checkUncheckIndex withObject:barButtonItem];
		
        toolBar.items = toolbarItems;
		
	}
	
	void add(UIView* xview)
	{
		UIToolbar* toolBar = (UIToolbar*)uiView;
		NSMutableArray *toolbarItems = [[NSMutableArray arrayWithArray:toolBar.items] retain];
		long c = [toolbarItems count];
		c = c+1;
		xview.tag = c;
		
		UIBarButtonItem *xv = [[UIBarButtonItem alloc] initWithCustomView:xview];

		[toolbarItems addObject:xv];
		[xv release];
		
		
		
        //[toolbarItems addObject:view];
		[(UIToolbar*)uiView setItems:toolbarItems];
	}
	

	/*
	void setValue(float value)
	{
		[(UISlider*)uiView setValue:value];
	}
	
	void setThumbImage(NSString* imagefile)
	{
		//NSLog(imagefile);
		//UIImage *sliderThumb = [UIImage imageNamed:imagefile];
		UIImage *sliderThumb = [[[UIImage alloc] initWithContentsOfFile:imagefile] autorelease];
		[(UISlider*)uiView setThumbImage:sliderThumb forState:UIControlStateNormal];
		[(UISlider*)uiView setThumbImage:sliderThumb forState:UIControlStateHighlighted];
	}
	
	*/
	
};

//----------------------------------------------------------------------------------------------
class ToolbarBinder
{
public:
	ToolbarBinder(lua_State* L);
	
private:
	static int create(lua_State* L);
	static int destruct(lua_State* L);
	static int addButton(lua_State* L);
	static int addTextButton(lua_State* L);
	static int add(lua_State* L);
	//static int getValue(lua_State* L);
	//static int setThumbImage(lua_State* L);
};

ToolbarBinder::ToolbarBinder(lua_State* L)
{
	const luaL_Reg functionlist[] = {
		{"addButton", addButton},
		{"addTextButton", addTextButton},
		{"add", add},
		//{"setThumbImage", setThumbImage},
		{NULL, NULL},
	};
	
	g_createClass(L, "Toolbar", "View", create, destruct, functionlist);	
}

int ToolbarBinder::create(lua_State* L)
{
	//float min = luaL_checknumber(L, 1);
	//float max = luaL_checknumber(L, 2);
	Toolbar* bar = new Toolbar(L);
	bar->create();
	
	g_pushInstance(L, "Toolbar", bar->object());
	
	setObject(L, bar);
	
	return 1;
}

int ToolbarBinder::destruct(lua_State* L)
{
	void* ptr = *(void**)lua_touserdata(L, 1);
	GReferenced* object = static_cast<GReferenced*>(ptr);
	Toolbar* toolbar = static_cast<Toolbar*>(object->proxy());
	
	toolbar->unref(); 
	
	return 0;
}

int ToolbarBinder::addButton(lua_State* L)
{
	GReferenced* tbObject = static_cast<GReferenced*>(g_getInstance(L, "Toolbar", 1));
	Toolbar* tbar = static_cast<Toolbar*>(tbObject->proxy());
	//float value = luaL_checknumber(L, 2);
	tbar->addButton();
	return 0;
}
int ToolbarBinder::addTextButton(lua_State* L)
{
	GReferenced* tbObject = static_cast<GReferenced*>(g_getInstance(L, "Toolbar", 1));
	Toolbar* tbar = static_cast<Toolbar*>(tbObject->proxy());
	const char* caption = luaL_checkstring(L, 2);
	tbar->addTextButton([NSString stringWithUTF8String:caption]);
	return 0;
}

int ToolbarBinder::add(lua_State* L)
{
	GReferenced* tbObject = static_cast<GReferenced*>(g_getInstance(L, "Toolbar", 1));
	Toolbar* tbar = static_cast<Toolbar*>(tbObject->proxy());
	
	GReferenced* viewObject = static_cast<GReferenced*>(g_getInstance(L, "View", 2));
	View* view = static_cast<View*>(viewObject->proxy());
	UIView* uiView = view->uiView;
	tbar->add(uiView);
	return 0;
}

//----------------------------------------------------------------------------------------------
#pragma mark ---- UIButton ----

class Button : public View
{
public:
	Button(lua_State* L) : View(L)
	{
		selectorToEvent.type = @"onButtonClick";		
	}
	
	virtual ~Button()
	{
		[(UIButton*)uiView removeTarget:selectorToEvent action:@selector(event:) forControlEvents:UIControlEventTouchUpInside];
	}
	
	virtual void create()	
	{
		UIButton* button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
		//button.tag = 22;
		[button addTarget:selectorToEvent action:@selector(event:) forControlEvents:UIControlEventTouchUpInside];
		//[[[(UIButton*)uiView ]titleLabel] font:[UIFont systemFontOfSize: 12]];
		
		[button retain];
	
		uiView = button;
		
	}
	
	void setTitle(NSString* title)
	{
		[(UIButton*)uiView setTitle:title forState:UIControlStateNormal];
	}
	
	void setTitleColor(CGFloat r, CGFloat g, CGFloat b)
	{
		UIColor *color = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
		[(UIButton*)uiView setTitleColor:color forState:UIControlStateNormal];
	}
	
	void setBGColor(CGFloat r, CGFloat g, CGFloat b)
	{
		UIColor *color = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
		[(UIButton*)uiView setBackgroundColor:color];
	}
	
	void setFont(NSString* fontname, CGFloat s)
	{
		//[[(UIButton*)uiView titleLabel] setFont:[UIFont systemFontOfSize:size]];
		[[(UIButton*)uiView titleLabel] setFont:[UIFont fontWithName:fontname size:s]];
		//[button.titleLabel setFont:[UIFont fontWithName:@"Arial-BoldMT" size:12]];

	}
	
	
	void setImage(NSString* imagefile)
	{
		UIImage *img = [[[UIImage alloc] initWithContentsOfFile:imagefile] autorelease];
		//[(UIButton*)uiView setBackgroundImage:img forState:UIControlStateNormal];
		[(UIButton*)uiView setImage:img forState:UIControlStateHighlighted];
	}
	
	void setBGImage(NSString* imagefile)
	{
		UIImage *img = [[[UIImage alloc] initWithContentsOfFile:imagefile] autorelease];
		[(UIButton*)uiView setBackgroundImage:img forState:UIControlStateNormal];
		//[(UIButton*)uiView setImage:img forState:UIControlStateHighlighted];
	}
	
};

//----------------------------------------------------------------------------------------------
class ButtonBinder
{
public:
	ButtonBinder(lua_State* L);
	
private:
	static int create(lua_State* L);
	static int destruct(lua_State* L);
	static int setTitle(lua_State* L);
	static int setTitleColor(lua_State* L);
	static int setBGColor(lua_State* L);
	static int setFont(lua_State* L);
	static int setImage(lua_State* L);
	static int setBGImage(lua_State* L);
};

ButtonBinder::ButtonBinder(lua_State* L)
{
	const luaL_Reg functionlist[] = {
		{"setTitle", setTitle},
		{"setTitleColor", setTitleColor},
		{"setBGColor", setBGColor},
		{"setFont", setFont},
		{"setImage", setImage},
		{"setBGImage", setBGImage},
		{NULL, NULL},
	};
	
	g_createClass(L, "Button", "View", create, destruct, functionlist);	
}

int ButtonBinder::create(lua_State* L)
{
	Button* button = new Button(L);
	button->create();
	
	g_pushInstance(L, "Button", button->object());
	
	setObject(L, button);
	
	return 1;
}

int ButtonBinder::destruct(lua_State* L)
{
	void* ptr = *(void**)lua_touserdata(L, 1);
	GReferenced* object = static_cast<GReferenced*>(ptr);
	Button* button = static_cast<Button*>(object->proxy());
	
	button->unref(); 
	
	return 0;
}

int ButtonBinder::setTitle(lua_State* L)
{
	GReferenced* buttonObject = static_cast<GReferenced*>(g_getInstance(L, "Button", 1));
	Button* button = static_cast<Button*>(buttonObject->proxy());
	
	const char* title = luaL_checkstring(L, 2);
	button->setTitle([NSString stringWithUTF8String:title]);
	
	return 0;
}

int ButtonBinder::setTitleColor(lua_State* L)
{
	GReferenced* buttonObject = static_cast<GReferenced*>(g_getInstance(L, "Button", 1));
	Button* button = static_cast<Button*>(buttonObject->proxy());
	
	float red = luaL_checknumber(L, 2);
	float green = luaL_checknumber(L, 3);
	float blue = luaL_checknumber(L, 4);
	button->setTitleColor(red, green, blue);
	
	return 0;
}

int ButtonBinder::setBGColor(lua_State* L)
{
	GReferenced* buttonObject = static_cast<GReferenced*>(g_getInstance(L, "Button", 1));
	Button* button = static_cast<Button*>(buttonObject->proxy());
	
	float red = luaL_checknumber(L, 2);
	float green = luaL_checknumber(L, 3);
	float blue = luaL_checknumber(L, 4);
	button->setBGColor(red, green, blue);
	
	return 0;
}

int ButtonBinder::setFont(lua_State* L)
{
	GReferenced* buttonObject = static_cast<GReferenced*>(g_getInstance(L, "Button", 1));
	Button* button = static_cast<Button*>(buttonObject->proxy());
	
	const char* name = luaL_checkstring(L, 2);
	float size = luaL_checknumber(L, 3);
	button->setFont([NSString stringWithUTF8String:name], size);
	
	return 0;
}


int ButtonBinder::setBGImage(lua_State* L)
{
	GReferenced* buttonObject = static_cast<GReferenced*>(g_getInstance(L, "Button", 1));
	Button* button = static_cast<Button*>(buttonObject->proxy());
	
	const char* imagename = luaL_checkstring(L, 2);
	
	button->setBGImage([NSString stringWithUTF8String:g_pathForFile(imagename)]);
	return 0;
}

int ButtonBinder::setImage(lua_State* L)
{
	GReferenced* buttonObject = static_cast<GReferenced*>(g_getInstance(L, "Button", 1));
	Button* button = static_cast<Button*>(buttonObject->proxy());
	
	const char* imagename = luaL_checkstring(L, 2);
	
	button->setImage([NSString stringWithUTF8String:g_pathForFile(imagename)]);
	return 0;
}

//----------------------------------------------------------------------------------------------
#pragma mark ---- UIScrollView ----

class ScrollView : public View
{
public:
	ScrollView(lua_State* L) : View(L)
	{
		selectorToEvent.type = @"onScrollViewClick";		
	}
	
	virtual ~ScrollView()
	{
	}
	
	virtual void create(CGFloat x,CGFloat y,CGFloat w,CGFloat h,CGFloat cw, CGFloat ch)	
	{
		CGRect scrollViewFrame = CGRectMake(x, y, w, h);
		UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:scrollViewFrame];
		
		CGSize scrollViewContentSize = CGSizeMake(cw, ch);
		[scrollView setContentSize:scrollViewContentSize];
		[scrollView retain];
		
		uiView = scrollView;
	}
	
	void add(UIView* v)
	{
		[(UIScrollView*)uiView addSubview:v];
	}
	

};

//----------------------------------------------------------------------------------------------
class ScrollViewBinder
{
public:
	ScrollViewBinder(lua_State* L);
	
private:
	static int create(lua_State* L);
	static int destruct(lua_State* L);
	static int add(lua_State* L);
};

ScrollViewBinder::ScrollViewBinder(lua_State* L)
{
	const luaL_Reg functionlist[] = {
		{"add", add},
		{NULL, NULL},
	};
	
	g_createClass(L, "ScrollView", "View", create, destruct, functionlist);	
}

int ScrollViewBinder::create(lua_State* L)
{
	ScrollView* scroll = new ScrollView(L);
	float x = luaL_checknumber(L, 1);
	float y = luaL_checknumber(L, 2);
	float w = luaL_checknumber(L, 3);
	float h = luaL_checknumber(L, 4);
	float cw = luaL_checknumber(L, 5);
	float ch = luaL_checknumber(L, 6);
	scroll->create(x,y,w,h,cw,ch);
	
	g_pushInstance(L, "ScrollView", scroll->object());
	
	setObject(L, scroll);
	
	return 1;
}

int ScrollViewBinder::destruct(lua_State* L)
{
	void* ptr = *(void**)lua_touserdata(L, 1);
	GReferenced* object = static_cast<GReferenced*>(ptr);
	ScrollView* scroll = static_cast<ScrollView*>(object->proxy());
	
	scroll->unref(); 
	
	return 0;
}

int ScrollViewBinder::add(lua_State* L)
{
	GReferenced* scrollObject = static_cast<GReferenced*>(g_getInstance(L, "ScrollView", 1));
	ScrollView* scroll = static_cast<ScrollView*>(scrollObject->proxy());

	GReferenced* viewObject = static_cast<GReferenced*>(g_getInstance(L, "View", 2));
	View* view = static_cast<View*>(viewObject->proxy());
	UIView* uiView = view->uiView;
	scroll->add(uiView);
	
//Michael Hartlef 20120303 - This need to be added to have views that are added the scroll view not be garbage collected >>>>>>>
	topUIViews.insert(uiView);
	
	lua_pushlightuserdata(L, (void *)&KEY_ROOTOBJECTS);
	lua_rawget(L, LUA_REGISTRYINDEX);
	lua_pushlightuserdata(L, view);
	lua_pushvalue(L, 2);
	lua_rawset(L, -3);
	lua_pop(L, 1);
//Michael Hartlef 20120303 <<<<<<<<<<
	
	
	
	
	return 0;
}

//----------------------------------------------------------------------------------------------
#pragma mark ---- UILabel ----

class Label : public View
{
public:
	Label(lua_State* L) : View(L)
	{
		selectorToEvent.type = @"onLabelClick";		
	}
	
	virtual ~Label()
	{
	}
	
	virtual void create()	
	{
		UILabel* label = [[UILabel alloc] init];
		[label setFont:[UIFont systemFontOfSize: 12]];
		[label setTextAlignment:UITextAlignmentLeft];
		[label setNumberOfLines:1];
		[label retain];
		
		uiView = label;
	}
	
	void setText(NSString* text)
	{
		[(UILabel*)uiView setText:text];
		//[(UILabel*)uiView sizeToFit];
	}
	
	void setTextColor(CGFloat r, CGFloat g, CGFloat b)
	{
		UIColor *color = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
		[(UILabel*)uiView setTextColor:color];
	}
	
	void setBGColor(CGFloat r, CGFloat g, CGFloat b)
	{
		UIColor *color = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
		[(UILabel*)uiView setBackgroundColor:color];
	}
	
	
		
	void setFont(NSString* fontname, CGFloat s)
	{
		[(UILabel*)uiView setFont:[UIFont fontWithName:fontname size:s]];
	}
};

//----------------------------------------------------------------------------------------------
class LabelBinder
{
public:
	LabelBinder(lua_State* L);
	
private:
	static int create(lua_State* L);
	static int destruct(lua_State* L);
	static int setText(lua_State* L);
	static int setTextColor(lua_State* L);
	static int setBGColor(lua_State* L);
	static int setFont(lua_State* L);
};

LabelBinder::LabelBinder(lua_State* L)
{
	const luaL_Reg functionlist[] = {
		{"setText", setText},
		{"setTextColor", setTextColor},
		{"setBGColor", setBGColor},
		{"setFont", setFont},
		{NULL, NULL},
	};
	
	g_createClass(L, "Label", "View", create, destruct, functionlist);	
}

int LabelBinder::create(lua_State* L)
{
	Label* label = new Label(L);
	label->create();
	
	g_pushInstance(L, "Label", label->object());
	
	setObject(L, label);
	
	return 1;
}

int LabelBinder::destruct(lua_State* L)
{
	void* ptr = *(void**)lua_touserdata(L, 1);
	GReferenced* object = static_cast<GReferenced*>(ptr);
	Label* label = static_cast<Label*>(object->proxy());
	
	label->unref(); 
	
	return 0;
}

int LabelBinder::setText(lua_State* L)
{
	GReferenced* labelObject = static_cast<GReferenced*>(g_getInstance(L, "Label", 1));
	Label* label = static_cast<Label*>(labelObject->proxy());
	
	const char* title = luaL_checkstring(L, 2);
	label->setText([NSString stringWithUTF8String:title]);
	return 0;
}

int LabelBinder::setTextColor(lua_State* L)
{
	GReferenced* labelObject = static_cast<GReferenced*>(g_getInstance(L, "Label", 1));
	Label* label = static_cast<Label*>(labelObject->proxy());
	
	float red = luaL_checknumber(L, 2);
	float green = luaL_checknumber(L, 3);
	float blue = luaL_checknumber(L, 4);
	label->setTextColor(red, green, blue);
	
	return 0;
}

int LabelBinder::setBGColor(lua_State* L)
{
	GReferenced* labelObject = static_cast<GReferenced*>(g_getInstance(L, "Label", 1));
	Label* label = static_cast<Label*>(labelObject->proxy());
	
	float red = luaL_checknumber(L, 2);
	float green = luaL_checknumber(L, 3);
	float blue = luaL_checknumber(L, 4);
	label->setBGColor(red, green, blue);
	return 0;
}

int LabelBinder::setFont(lua_State* L)
{
	GReferenced* labelObject = static_cast<GReferenced*>(g_getInstance(L, "Label", 1));
	Label* label = static_cast<Label*>(labelObject->proxy());
	
	const char* name = luaL_checkstring(L, 2);
	float size = luaL_checknumber(L, 3);
	label->setFont([NSString stringWithUTF8String:name], size);
	
	return 0;
}


#pragma mark ---- UITableView ----
//----------------------------------------------------------------------------------------------
//-------------------------------------------//
//------- UITableView begins here -----------//
//-------------------------------------------//

@interface UITableViewDelegate : NSObject<UITableViewDelegate, UITableViewDataSource>
{
	lua_State* L;
	GReferenced* target;
}

@property (nonatomic, assign) GReferenced* target;
@property (nonatomic, assign) lua_State* L;
@property (nonatomic, retain) NSArray *dataArray;
@property (nonatomic, assign) NSString *cellText;

@end

@implementation UITableViewDelegate

@synthesize target;
@synthesize L;
@synthesize dataArray;
@synthesize cellText;

//delegate methods
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	getObject(L, target);
	if (!lua_isnil(L, -1))
	{
		lua_getfield(L, -1, "dispatchEvent");
		lua_pushvalue(L, -2);
		lua_getglobal(L, "Event");
		lua_getfield(L, -1, "new");
		lua_remove(L, -2);
		lua_pushstring(L, "didSelectRowAtIndexPath");
		lua_call(L, 1, 1);
		
        lua_pushinteger(L, indexPath.row);
        lua_setfield(L, -2, "Row");
		if (lua_pcall(L, 2, 0, 0) != 0)
		{
			g_error(L, lua_tostring(L, -1));
			return;
		}
	}
	lua_pop(L, 1);	
    return;
}

//datasource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return dataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    
    //send an event so that the cell can be formatted
    getObject(L, target);
	if (!lua_isnil(L, -1))
	{
		lua_getfield(L, -1, "dispatchEvent");
		lua_pushvalue(L, -2);
		lua_getglobal(L, "Event");
		lua_getfield(L, -1, "new");
		lua_remove(L, -2);
		lua_pushstring(L, "cellForRowAtIndexPath");
		lua_call(L, 1, 1);
		
        lua_pushinteger(L, indexPath.row);
        lua_setfield(L, -2, "Row");
		if (lua_pcall(L, 2, 0, 0) != 0)
		{
			g_error(L, lua_tostring(L, -1));
			return nil;
		}
	}
	lua_pop(L, 1);	

    //cellText is set by calling tableView:setCellText() from the 
    //Gideros event function called above
    cell.textLabel.text = self.cellText;
    return cell;
}

-(void)dealloc
{
    [dataArray release];
    [super dealloc];
}

@end


//----------------------------------------------------------------------------------------------
class TableView : public View
{
public:
	TableView(lua_State* L) : View(L)
	{
		selectorToEvent.type = @"onLabelClick";	
        delegate = [[UITableViewDelegate alloc] init];
        delegate.L = L;
        delegate.target = this;
	}
	
	virtual ~TableView()
	{
        NSLog(@"TableView destructor");
        UITableView *tableView = (UITableView *)uiView;
        tableView.delegate = nil;
        tableView.dataSource = nil;
        [delegate release];
	}
	
	virtual void create()	
	{
        UITableView *tableView = [[UITableView alloc] init];
        tableView.delegate = delegate;
        tableView.dataSource = delegate;
		uiView = tableView;
	}
    
    void setData(NSArray *array)
    {
        delegate.dataArray = array;
        UITableView *tableView = (UITableView *)uiView;
        [tableView reloadData];
    }
    
    void setCellText(NSString *text)
    {
        delegate.cellText = text;
    }
    
private:
    lua_State *L;
    UITableViewDelegate *delegate;
};

//----------------------------------------------------------------------------------------------
class TableViewBinder
{
public:
	TableViewBinder(lua_State* L);
	
private:
	static int create(lua_State* L);
	static int destruct(lua_State* L);
    
    static int setData(lua_State *L);
    static int setCellText(lua_State *L);
};

TableViewBinder::TableViewBinder(lua_State* L)
{
	const luaL_Reg functionlist[] = {
        {"setData", setData},
        {"setCellText", setCellText},
		{NULL, NULL},
	};
	
	g_createClass(L, "TableView", "View", create, destruct, functionlist);	
}

int TableViewBinder::create(lua_State* L)
{
    TableView *tableView = new TableView(L);
	tableView->create();
	
	g_pushInstance(L, "TableView", tableView->object());
	
	setObject(L, tableView);
	return 1;
}

int TableViewBinder::destruct(lua_State* L)
{
	void* ptr = *(void**)lua_touserdata(L, 1);
	GReferenced* object = static_cast<GReferenced*>(ptr);
	TableView* tableView = static_cast<TableView*>(object->proxy());
	tableView->unref(); 
	
	return 0;
}

int TableViewBinder::setData(lua_State* L)
{
    GReferenced* tableViewObject = static_cast<GReferenced*>(g_getInstance(L, "Label", 1));
	TableView *tableView = static_cast<TableView*>(tableViewObject->proxy());

    NSArray *array = (NSArray *)lua_touserdata(L, 2);
    tableView->setData(array);
    return 0;
}

int TableViewBinder::setCellText(lua_State *L)
{
    GReferenced* tableViewObject = static_cast<GReferenced*>(g_getInstance(L, "Label", 1));
	TableView *tableView = static_cast<TableView*>(tableViewObject->proxy());
    
    //pop the text value from the stack
    NSString *text = [NSString stringWithUTF8String:luaL_checkstring(L, -1)];
    tableView->setCellText(text);
    return 0;
}


//----------------------------------------------------------------------------------------------
#pragma mark ---- UIWebView ----

//-------------------------------------------//
//------- UIWebView begins here -----------//
//-------------------------------------------//

@interface UIWebViewDelegate : NSObject<UIWebViewDelegate>
{
	lua_State* L;
	GReferenced* target;
}

@property (nonatomic, assign) GReferenced* target;
@property (nonatomic, assign) lua_State* L;

- (void)webViewDidStartLoad:(UIWebView *)webView;
- (void)webViewDidFinishLoad:(UIWebView *)webView;

@end

@implementation UIWebViewDelegate

@synthesize target;
@synthesize L;

- (void)webViewDidStartLoad:(UIWebView *)webView
{
	// starting the load, show the activity indicator in the status bar
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	// finished loading, hide the activity indicator in the status bar
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	// load error, hide the activity indicator in the status bar
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	
	// report the error inside the webview
	NSString* errorString = [NSString stringWithFormat:
							 @"<html><center><font size=+5 color='red'>An error occurred:<br>%@</font></center></html>",
							 error.localizedDescription];
	[webView loadHTMLString:errorString baseURL:nil];
}


- (BOOL)webView:(UIWebView*)webView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSString *type;
	NSLog(@"shouldStartLoadWithRequest");

		getObject(L, target);
		
		if (!lua_isnil(L, -1))
		{
			lua_getfield(L, -1, "dispatchEvent");
			
			lua_pushvalue(L, -2);
			
			lua_getglobal(L, "Event");
			lua_getfield(L, -1, "new");
			lua_remove(L, -2);
			lua_pushstring(L, "onWebViewNavigation");
			lua_call(L, 1, 1);
			
			switch(navigationType)
			{
				case UIWebViewNavigationTypeLinkClicked:
					type = @"LinkClicked";
					break;
				case UIWebViewNavigationTypeFormSubmitted:
					type = @"FormSubmitted";
					break;
				case UIWebViewNavigationTypeFormResubmitted:
					type = @"FormResubmitted";
					break;
				case UIWebViewNavigationTypeReload:
					type = @"Reload";
					break;
				case UIWebViewNavigationTypeBackForward:
					type = @"BackForward";
					break;
				default:
					type = @"Other";
					break;
			}
			
		
			lua_pushstring(L, [type UTF8String]);
			lua_setfield(L, -2, "Type");
			
			NSURL *url = [request URL];
			NSString *xurl = [url absoluteString];
			lua_pushstring(L, [xurl UTF8String]);
			
			lua_setfield(L, -2, "Url");
			
			if (lua_pcall(L, 2, 0, 0) != 0)
			{
				g_error(L, lua_tostring(L, -1));
				return true;
			}

		
		lua_pop(L, 1);	

	}
	return true;
}

@end


class WebView : public View
{
public:
	WebView(lua_State* L) : View(L)
	{
		delegate = [[UIWebViewDelegate alloc] init];
		delegate.L = L;
		delegate.target = this;
	}
	
	virtual ~WebView()
	{
		webView.delegate = nil;
		[delegate release];
		[webView release];
	}
	
	virtual void create(NSString* xurl)	
	{
		
		CGRect webFrame = CGRectMake(10.0, 10.0, 300.0, 440.0);
		webView = [[UIWebView alloc] initWithFrame:webFrame];
		//[webView setBackgroundColor:[UIColor greenColor]];
		//NSString *encodedUrl = [xurl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding ]; 
		
		[webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:xurl]]];
		webView.scalesPageToFit = YES;
		webView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
		
		[webView setDelegate:delegate];
		[webView retain];
		
		uiView = webView;
		
	}
	


	void loadLocalFile(NSString* filename)
	{
		//[webView addButtonWithTitle:title];
		NSLog(@"%@", filename);
		[webView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:filename]]];
	
	}
	
private:
	lua_State* L;
	UIWebView* webView;
	UIWebViewDelegate* delegate;
};

class WebViewBinder : public GEventDispatcherProxy
{
public:
	WebViewBinder(lua_State* L);
	
private:
	static int create(lua_State* L);
	static int destruct(lua_State* L);
	static int loadLocalFile(lua_State* L);
};


WebViewBinder::WebViewBinder(lua_State* L)
{
	const luaL_Reg functionlist[] = {
		{"loadLocalFile", loadLocalFile},
		{NULL, NULL},
	};
	
	g_createClass(L, "WebView", "View", create, destruct, functionlist);	
}

int WebViewBinder::create(lua_State* L)
{
	const char* text = luaL_checkstring(L, 1);
	
	WebView* view = new WebView(L);
	
	view->create([NSString stringWithUTF8String:text]);
	
	
	g_pushInstance(L, "WebView", view->object());
	
	setObject(L, view);
	return 1;
}


int WebViewBinder::destruct(lua_State* L)
{
	void* ptr = *(void**)lua_touserdata(L, 1);
	GReferenced* object = static_cast<GReferenced*>(ptr);
	WebView* webObject = static_cast<WebView*>(object->proxy());
	
	webObject->unref(); 
	
	return 0;
}

int WebViewBinder::loadLocalFile(lua_State* L)
{
	GReferenced* viewObject = static_cast<GReferenced*>(g_getInstance(L, "WebView", 1));
	WebView* view = static_cast<WebView*>(viewObject->proxy());
	const char* filename = luaL_checkstring(L, 2);
	
	view->loadLocalFile([NSString stringWithUTF8String:g_pathForFile(filename)]);
	return 0;
}

//-------------------------------------------//
//------- UIWebView ends here -------------//
//-------------------------------------------//


//----------------------------------------------------------------------------------------------
#pragma mark ---- UIPickerView ----

//-------------------------------------------//
//------- UIPickerView begins here -----------//
//-------------------------------------------//

@interface UIPickerViewDelegate : UIViewController<UIPickerViewDataSource, UIPickerViewDelegate>
{
	lua_State* L;
	GReferenced* target;

}

@property (nonatomic, assign) GReferenced* target;
@property (nonatomic, assign) lua_State* L;


- (BOOL)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component;
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component;
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView ;
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component; 
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component; 

@end

@implementation UIPickerViewDelegate

@synthesize target;
@synthesize L;

NSMutableArray *rowNames = [NSMutableArray array];

- (BOOL)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component {
    
    // Handle the selection
    
    getObject(L, target);
	
	if (!lua_isnil(L, -1))
	{
		lua_getfield(L, -1, "dispatchEvent");
		
		lua_pushvalue(L, -2);
		
		lua_getglobal(L, "Event");
		lua_getfield(L, -1, "new");
		lua_remove(L, -2);
		lua_pushstring(L, "onPickerRows");
		lua_call(L, 1, 1);
       
        NSString *text = [rowNames objectAtIndex:row];
		lua_pushstring(L, [text UTF8String]);
        lua_setfield(L, -2, "item");
		
		if (lua_pcall(L, 2, 0, 0) != 0)
		{
			g_error(L, lua_tostring(L, -1));
			return true;
		}
	}
	
	lua_pop(L, 1);	
    
    return YES;
    
}

// tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
   
    return [rowNames count];
    
}

// tell the picker how many components it will have
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
     
    return 1;
    
}

// tell the picker the title for a given component
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    
    return [rowNames objectAtIndex:row];
  
}

// tell the picker the width of each row for a given component
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
    
    return 300;
    
}

@end

class PickerView : public View
{
public:
	PickerView(lua_State* L) : View(L)
	{
        
		delegate = [[UIPickerViewDelegate alloc] init];
		delegate.L = L;
		delegate.target = this;
       
        [rowNames removeAllObjects];
               
        //push nil onto the stack so that the while loop will work
        lua_pushnil(L);
        
        if (lua_isnil(L, 1)) {
        
            [rowNames addObject:@"Error! - No Table"];
            return;
            
        }
        //move the table into an NSMutableArray
        while (lua_next(L, 1) != 0) {
          
            //==3 value - sort this -1==
            //==2 key - key -2==
            //==1 tableToBeSorted -3==
            
            NSString *value = [NSString stringWithUTF8String:luaL_checkstring(L, -1)];
            [rowNames addObject:value];
            
            //removes 'value'; keeps 'key' for next iteration
            lua_pop(L, 1);
        }
        
            

    }
	
	virtual ~PickerView()
	{
		pickerView.delegate = nil;

		[delegate release];
		[pickerView release];
 
	}
	
	virtual void create()	
	{
                       
	    pickerView = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 240 - 72, 320, 240 - 72)];
		[pickerView setDelegate:delegate];
       
		pickerView.showsSelectionIndicator = YES;
		
		[pickerView retain];
       
		uiView = pickerView;
		
	}
    
    virtual NSInteger getRowCount()	
	{
		return [rowNames count];
		
	}
    
    virtual void setRow(NSInteger row)	
	{
		[pickerView selectRow:row - 1 inComponent:0 animated:YES]; // make 1 .. N to 0 to N .. 1
		
	}

    
    virtual NSInteger getPickedRow()	
	{
        
        return [pickerView selectedRowInComponent:0] + 1; // make 0 .. N - 1 to 1 .. N
		
	}

    virtual NSString* getPickedItem()	
	{
        
        return [rowNames objectAtIndex:[pickerView selectedRowInComponent:0]];
		
	}

	
private:
	lua_State* L;
	UIPickerView* pickerView;
	UIPickerViewDelegate* delegate;
};


class PickerViewBinder : public GEventDispatcherProxy
{
public:
	PickerViewBinder(lua_State* L);
	
private:
	static int create(lua_State* L);
	static int destruct(lua_State* L);
    static int getRowCount(lua_State* L);    
    static int setRow(lua_State* L);
    static int getPickedRow(lua_State* L);
    static int getPickedItem(lua_State* L);
};


PickerViewBinder::PickerViewBinder(lua_State* L)
{
	const luaL_Reg functionlist[] = {
        {"getRowCount", getRowCount},
        {"setRow", setRow},
        {"getPickedRow", getPickedRow},
        {"setRow", setRow},
        {"getPickedItem", getPickedItem},
		{NULL, NULL},
	};
	
	g_createClass(L, "PickerView", "View", create, destruct, functionlist);	
}

int PickerViewBinder::create(lua_State* L)
{
	//const char* text = luaL_checkstring(L, 1);
	
	PickerView* view = new PickerView(L);
	
	view->create(/*[NSString stringWithUTF8String:text]*/);
	
	g_pushInstance(L, "PickerView", view->object());
	
	setObject(L, view);
    
	return 1;
}


int PickerViewBinder::destruct(lua_State* L)
{
	void* ptr = *(void**)lua_touserdata(L, 1);
	GReferenced* object = static_cast<GReferenced*>(ptr);
	PickerView* pickerObject = static_cast<PickerView*>(object->proxy());
	
	pickerObject->unref(); 
	
	return 0;
}


int PickerViewBinder::getRowCount(lua_State* L)
{
	GReferenced* object = static_cast<GReferenced*>(g_getInstance(L, "PickerView", 1));
	PickerView* pickerObject = static_cast<PickerView*>(object->proxy());
    
	NSInteger count = pickerObject->getRowCount();
    lua_pushinteger(L, count);
    
	return 1;
}

int PickerViewBinder::setRow(lua_State* L)
{
	GReferenced* object = static_cast<GReferenced*>(g_getInstance(L, "PickerView", 1));
	PickerView* pickerObject = static_cast<PickerView*>(object->proxy());
    
    NSInteger i = luaL_checkint(L, 2);

	pickerObject->setRow(i); 
    
	return 0;
    
}



int PickerViewBinder::getPickedRow(lua_State* L)
{
	GReferenced* object = static_cast<GReferenced*>(g_getInstance(L, "PickerView", 1));
	PickerView* pickerObject = static_cast<PickerView*>(object->proxy());
    
	NSInteger count = pickerObject->getPickedRow();
    lua_pushinteger(L, count);
    
	return 1;
}


int PickerViewBinder::getPickedItem(lua_State* L)
{
	GReferenced* object = static_cast<GReferenced*>(g_getInstance(L, "PickerView", 1));
	PickerView* pickerObject = static_cast<PickerView*>(object->proxy());
    
	NSString *txt = pickerObject->getPickedItem();
	lua_pushstring(L, [txt UTF8String]);
    
	return 1;
}

//-------------------------------------------//
//------- UIPickerView ends here -------------//
//-------------------------------------------//



//----------------------------------------------------------------------------------------------
#pragma mark ---- UITextField ----

//-------------------------------------------//
//------- UITextField begins here -----------//
//-------------------------------------------//

@interface UITextFieldDelegate : NSObject<UITextFieldDelegate>
{
	lua_State* L;
	GReferenced* target;
}

@property (nonatomic, assign) GReferenced* target;
@property (nonatomic, assign) lua_State* L;

- (BOOL)textFieldShouldReturn:(UITextField *)textField;

@end

@implementation UITextFieldDelegate

@synthesize target;
@synthesize L;

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{

	getObject(L, target);
	
	if (!lua_isnil(L, -1))
	{
		lua_getfield(L, -1, "dispatchEvent");
		
		lua_pushvalue(L, -2);
		
		lua_getglobal(L, "Event");
		lua_getfield(L, -1, "new");
		lua_remove(L, -2);
		lua_pushstring(L, "onTextFieldReturn");
		lua_call(L, 1, 1);
		
		NSString *text = textField.text;
		lua_pushstring(L, [text UTF8String]);
		lua_setfield(L, -2, "text");
		
		if (lua_pcall(L, 2, 0, 0) != 0)
		{
			g_error(L, lua_tostring(L, -1));
			return true;
		}
	}
	
	lua_pop(L, 1);	

	//NSLog(@"TextField textFieldShouldReturn");
	[textField resignFirstResponder];
	
    return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
	
	getObject(L, target);
	
	if (!lua_isnil(L, -1))
	{
		lua_getfield(L, -1, "dispatchEvent");
		
		lua_pushvalue(L, -2);
		
		lua_getglobal(L, "Event");
		lua_getfield(L, -1, "new");
		lua_remove(L, -2);
		lua_pushstring(L, "onTextFieldEdit");
		lua_call(L, 1, 1);
		
		NSString *text = textField.text;
		lua_pushstring(L, [text UTF8String]);
		lua_setfield(L, -2, "text");
		
		if (lua_pcall(L, 2, 0, 0) != 0)
		{
			g_error(L, lua_tostring(L, -1));
			return true;
		}
	}
	
	lua_pop(L, 1);	
	
	//NSLog(@"TextField textFieldShouldEndEditing");
	
    return YES;
}

@end


class TextField2 : public View
{
public:
	TextField2(lua_State* L) : View(L)
	{
		delegate = [[UITextFieldDelegate alloc] init];
		delegate.L = L;
		delegate.target = this;
	}
	
	virtual ~TextField2()
	{
		textField.delegate = nil;
		[textField release];
		[delegate release];
	}
	
	virtual void create(NSString* text)	
	{
		textField = [[UITextField alloc] initWithFrame:CGRectMake(10, 100, 300, 30)];
		textField.placeholder = text;
		textField.returnKeyType = UIReturnKeyDone;
		textField.borderStyle = UITextBorderStyleBezel;
		textField.enablesReturnKeyAutomatically = TRUE;
		textField.delegate = delegate;
		
		[textField retain];
		
		uiView = textField;
		
	}
	
	virtual void setText(NSString* text)	
	{
		textField.text = text;
		
	}
	
	virtual NSString* getText()	
	{
		return textField.text;
		
	}
    
    virtual void setTextColor(CGFloat r, CGFloat g, CGFloat b)
	{
		UIColor *color = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
        textField.textColor = color; 
        			
	}
	
	virtual void setBGColor(CGFloat r, CGFloat g, CGFloat b)
	{
		UIColor *color = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
        textField.backgroundColor = color;

	}
	
	virtual void showKeyboard()
	{
        
		// set cursor and show keyboard
        [textField becomeFirstResponder];
        
	}
	
private:
	lua_State* L;
	UITextField* textField;
	UITextFieldDelegate* delegate;
};


class TextFieldBinder2 : public GEventDispatcherProxy
{
public:
	TextFieldBinder2(lua_State* L);
	
private:
	static int create(lua_State* L);
	static int destruct(lua_State* L);
	static int setText(lua_State* L);
	static int getText(lua_State* L);
    static int setTextColor(lua_State* L);
    static int setBGColor(lua_State* L);
    static int showKeyboard(lua_State* L);
};


TextFieldBinder2::TextFieldBinder2(lua_State* L)
{
	const luaL_Reg functionlist[] = {
		{"setText", setText},
		{"getText", getText},
        {"setTextColor", setTextColor},
		{"setBGColor", setBGColor},
		{"showKeyboard", showKeyboard},
		{NULL, NULL},
	};
	
	//g_createClass(L, "TextField", "EventDispatcher", create, destruct, functionlist);	
	g_createClass(L, "TextField2", "View", create, destruct, functionlist);	
}

int TextFieldBinder2::create(lua_State* L)
{
	const char* text = luaL_checkstring(L, 1);
	
	TextField2* textField = new TextField2(L);
	
	textField->create([NSString stringWithUTF8String:text]);
	
	
	g_pushInstance(L, "TextField2", textField->object());
	
	setObject(L, textField);
	return 1;
}



int TextFieldBinder2::destruct(lua_State* L)
{
	void* ptr = *(void**)lua_touserdata(L, 1);
	GReferenced* object = static_cast<GReferenced*>(ptr);
	TextField2* textField = static_cast<TextField2*>(object->proxy());
	
	textField->unref(); 
	
	return 0;
}

int TextFieldBinder2::setText(lua_State* L)
{
	GReferenced* textFieldObject = static_cast<GReferenced*>(g_getInstance(L, "TextField2", 1));
	TextField2* field = static_cast<TextField2*>(textFieldObject->proxy());
	//NSLog(@"Binder setText");
	const char* txt = luaL_checkstring(L, 2);
	//NSLog(@"Binder setText");
	field->setText([NSString stringWithUTF8String:txt]);
	
	return 0;
}

int TextFieldBinder2::getText(lua_State* L)
{
	GReferenced* textFieldObject = static_cast<GReferenced*>(g_getInstance(L, "TextField2", 1));
	TextField2* field = static_cast<TextField2*>(textFieldObject->proxy());

	NSString *txt = field->getText();
	NSLog(@"%@", txt);
	lua_pushstring(L, [txt UTF8String]);
    
	return 1;
}

int TextFieldBinder2::setTextColor(lua_State* L)
{
	GReferenced* textFieldObject = static_cast<GReferenced*>(g_getInstance(L, "TextField2", 1));
	TextField2* field = static_cast<TextField2*>(textFieldObject->proxy());
	
	float red = luaL_checknumber(L, 2);
	float green = luaL_checknumber(L, 3);
	float blue = luaL_checknumber(L, 4);
	field->setTextColor(red, green, blue);
	
	return 0;
}

int TextFieldBinder2::setBGColor(lua_State* L)
{
	GReferenced* textFieldObject = static_cast<GReferenced*>(g_getInstance(L, "TextField2", 1));
	TextField2* field = static_cast<TextField2*>(textFieldObject->proxy());
	
	float red = luaL_checknumber(L, 2);
	float green = luaL_checknumber(L, 3);
	float blue = luaL_checknumber(L, 4);
	field->setBGColor(red, green, blue);
    
	return 0;
}


int TextFieldBinder2::showKeyboard(lua_State* L)
{	
    GReferenced* textFieldObject = static_cast<GReferenced*>(g_getInstance(L, "TextField2", 1));
    TextField2* field = static_cast<TextField2*>(textFieldObject->proxy());
    field->showKeyboard();
    //NSLog(@"Binder showKeyboard");
    return 1;
}


//-------------------------------------------//
//------- UITextField ends here -------------//
//-------------------------------------------//



//----------------------------------------------------------------------------------------------
#pragma mark ---- UIAlertView ----

//-------------------------------------------//
//------- AlertView begins here -------------//
//-------------------------------------------//

@interface AlertViewDelegate : NSObject<UIAlertViewDelegate>
{
	lua_State* L;
	GReferenced* target;
}

@property (nonatomic, assign) GReferenced* target;
@property (nonatomic, assign) lua_State* L;

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex;

@end

@implementation AlertViewDelegate

@synthesize target;
@synthesize L;

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	getObject(L, target);
	
	if (!lua_isnil(L, -1))
	{
		lua_getfield(L, -1, "dispatchEvent");
		
		lua_pushvalue(L, -2);
		
		lua_getglobal(L, "Event");
		lua_getfield(L, -1, "new");
		lua_remove(L, -2);
		lua_pushstring(L, "complete");
		lua_call(L, 1, 1);
		
		lua_pushinteger(L, buttonIndex);
		lua_setfield(L, -2, "buttonIndex");
		
		
		NSString *title = [alertView buttonTitleAtIndex:buttonIndex];
		lua_pushstring(L, [title UTF8String]);
		lua_setfield(L, -2, "caption");
		
		
		
		if (lua_pcall(L, 2, 0, 0) != 0)
		{
			g_error(L, lua_tostring(L, -1));
			return;
		}
	}
	
	lua_pop(L, 1);	
}

@end


class AlertView : public GEventDispatcherProxy
{
public:
	AlertView(lua_State* L, NSString* title, NSString* message, NSString* button) : L(L)
	{
		delegate = [[AlertViewDelegate alloc] init];
		delegate.L = L;
		delegate.target = this;
		
		alertView = [[UIAlertView alloc] initWithTitle:title
										 message:message
										 delegate:delegate
										 cancelButtonTitle:button
										 otherButtonTitles:nil];
	}
	
	virtual ~AlertView()
	{
		alertView.delegate = nil;
		[alertView release];
		[delegate release];
	}
	
	void show()
	{
		[alertView show];
	}
	
	void addButton(NSString* title)
	{
		[alertView addButtonWithTitle:title];
	}

private:
	lua_State* L;
	UIAlertView* alertView;
	AlertViewDelegate* delegate;
};


class AlertViewBinder
{
public:
	AlertViewBinder(lua_State* L);

private:
	static int create(lua_State* L);
	static int destruct(lua_State* L);
	static int show(lua_State* L);
	static int addButton(lua_State* L);
};


AlertViewBinder::AlertViewBinder(lua_State* L)
{
	const luaL_Reg functionlist[] = {
		{"show", show},
		{"addButton", addButton},
		{NULL, NULL},
	};
	
	g_createClass(L, "AlertView", "EventDispatcher", create, destruct, functionlist);	
}

int AlertViewBinder::create(lua_State* L)
{
	const char* title = luaL_checkstring(L, 1);
	const char* message = luaL_checkstring(L, 2);
	const char* button = luaL_checkstring(L, 3);
		
	AlertView* alertView = new AlertView(L, [NSString stringWithUTF8String:title], [NSString stringWithUTF8String:message], [NSString stringWithUTF8String:button]);

	g_pushInstance(L, "AlertView", alertView->object());
	
	setObject(L, alertView);
	
	return 1;
}

int AlertViewBinder::destruct(lua_State* L)
{
	void* ptr = *(void**)lua_touserdata(L, 1);
	GReferenced* object = static_cast<GReferenced*>(ptr);
	AlertView* alertView = static_cast<AlertView*>(object->proxy());
	
	alertView->unref(); 
	
	return 0;
}

int AlertViewBinder::show(lua_State* L)
{
	GReferenced* alertViewObject = static_cast<GReferenced*>(g_getInstance(L, "AlertView", 1));
	AlertView* view = static_cast<AlertView*>(alertViewObject->proxy());

	view->show();
	
	return 0;
}

int AlertViewBinder::addButton(lua_State* L)
{
	GReferenced* alertViewObject = static_cast<GReferenced*>(g_getInstance(L, "AlertView", 1));
	AlertView* view = static_cast<AlertView*>(alertViewObject->proxy());
	
	const char* title = luaL_checkstring(L, 2);
	view->addButton([NSString stringWithUTF8String:title]);

	return 0;
}

//-------------------------------------------//
//------- AlertView ends here ---------------//
//-------------------------------------------//




//----------------------------------------------------------------------------------------------

static int hideStatusBar(lua_State* L)
{
	bool show = lua_toboolean(L, 1);
    [[UIApplication sharedApplication] setStatusBarHidden:show withAnimation: UIStatusBarAnimationNone];
	[[UIApplication sharedApplication] setStatusBarHidden:true withAnimation: UIStatusBarAnimationNone];	return 0;
}

static int addToRootView(lua_State* L)
{
	GReferenced* viewObject = static_cast<GReferenced*>(g_getInstance(L, "View", 1));
	View* view = static_cast<View*>(viewObject->proxy());
	UIView* uiView = view->uiView;
	
	UIViewController* controller = g_getRootViewController();	
	UIView* rootView = controller.view;
	[rootView addSubview:uiView];
	
	topUIViews.insert(uiView);
	
	lua_pushlightuserdata(L, (void *)&KEY_ROOTOBJECTS);
	lua_rawget(L, LUA_REGISTRYINDEX);
	lua_pushlightuserdata(L, view);
	lua_pushvalue(L, 1);
	lua_rawset(L, -3);
	lua_pop(L, 1);

	
	return 0;
}

static int removeFromRootView(lua_State* L)
{
	GReferenced* viewObject = static_cast<GReferenced*>(g_getInstance(L, "View", 1));
	View* view = static_cast<View*>(viewObject->proxy());
	UIView* uiView = view->uiView;
	
	UIViewController* controller = g_getRootViewController();
	UIView* rootView = controller.view;
	
	if (uiView.superview == rootView)
	{
		[uiView removeFromSuperview];
		
		topUIViews.erase(uiView);

		lua_pushlightuserdata(L, (void *)&KEY_ROOTOBJECTS);
		lua_rawget(L, LUA_REGISTRYINDEX);
		lua_pushlightuserdata(L, view);
		lua_pushnil(L);
		lua_rawset(L, -3);
		lua_pop(L, 1);		
	}
	
	return 0;
}

//Convenience function for UITableView data source
static int luaTableToArray(lua_State* L)
{
    NSMutableArray *array = [NSMutableArray array];

    //==1 Lua table -1==
    lua_pushnil(L);

    //==2 nil -1==
    //==1 Lua table -2==
    
    //move the table into an NSMutableArray
    while (lua_next(L, 1) != 0) {
        //==3 value -1==
        //==2 key - in an array, this is the index number -2==
        //==1 Lua table -3==
        
        id finalValue = nil;
        switch (lua_type(L, -1)) {
            case LUA_TNUMBER: {
                int value = lua_tonumber(L, -1);
                NSNumber *number = [NSNumber numberWithInt:value];
                finalValue = number;
                break;
            }
            case LUA_TBOOLEAN: {
                int value = lua_toboolean(L, -1);
                NSNumber *number = [NSNumber numberWithBool:value];
                finalValue = number;
                break;
            }
            case LUA_TSTRING: {
                NSString *value = [NSString stringWithUTF8String:luaL_checkstring(L, -1)];
                finalValue = value;
                break;
            }
        }
        [array addObject:finalValue];
        // remove value - key stays for lua_next
        lua_pop(L, 1);
    }
    
    lua_pushlightuserdata(L, array);
    //return the address of the array to Gideros Studio for use later
    return 1;
}


static int loader(lua_State* L)
{
	ViewBinder viewBinder(L);
	ButtonBinder buttonBinder(L);
	LabelBinder labelBinder(L);
	AlertViewBinder alertViewBinder(L);
	SwitchBinder switchBinder(L);
	SliderBinder sliderBinder(L);
	TextFieldBinder2 textFieldBinder2(L);
	WebViewBinder webViewBinder(L);
    PickerViewBinder PickerViewBinder(L);

	ToolbarBinder toolbarBinder(L);
	ScrollViewBinder scrollViewBinder(L);
    TableViewBinder tableViewBinder(L);
	
	lua_pushcfunction(L, hideStatusBar);
	lua_setglobal(L, "hideStatusBar");
	
	lua_pushcfunction(L, addToRootView);
	lua_setglobal(L, "addToRootView");
	
	lua_pushcfunction(L, removeFromRootView);
	lua_setglobal(L, "removeFromRootView");
	
    lua_pushcfunction(L, luaTableToArray);
	lua_setglobal(L, "luaTableToArray");
    
	createObjectsTable(L);
	createRootObjectsTable(L);

	return 0;
}	


static void g_initializePlugin(lua_State *L)
{
	lua_getglobal(L, "package");
	lua_getfield(L, -1, "preload");
	
	lua_pushcfunction(L, loader);
	lua_setfield(L, -2, "ui");
	
	lua_pop(L, 2);
}

static void g_deinitializePlugin(lua_State *L)
{
	[[UIApplication sharedApplication] setStatusBarHidden:true withAnimation: UIStatusBarAnimationNone];
	for (std::set<UIView*>::iterator iter = topUIViews.begin(); iter != topUIViews.end(); ++iter)
		[*iter removeFromSuperview];
	topUIViews.clear();
}

REGISTER_PLUGIN("Native UI", "1.0")
