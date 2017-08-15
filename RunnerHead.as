// generic character head script

// TODO: fix double includes properly, added the following line temporarily to fix include issues
#include "PaletteSwap.as"
#include "PixelOffsets.as"
#include "RunnerTextures.as"

const s32 NUM_HEADFRAMES = 4;
const s32 NUM_UNIQUEHEADS = 30;
const int FRAMES_WIDTH = 8 * NUM_HEADFRAMES;

//PlayerHeads mod
const string HEAD_PROP = "my head :)";
const string PROP_NAME_PREFIX = "head: ";
const string HEAD_PATH = "../Cache/head.png";
const string SUCCESS_WARN = "Your head was successfully loaded.";
const string NOT_FOUND_WARN = "No head was found in " + HEAD_PATH + ". To get a custom head, you must put it in this directory. For more help, visit the forums.";
const string WRONG_SIZE_WARN = "Your head must be 64 x 16. Please check your head in " + HEAD_PATH;



void onInit(CBlob@ this)
{
	this.addCommandID("send_head");
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params){
	if(getNet().isClient() && cmd == this.getCommandID("send_head")){
		CPlayer@ localPlayer = getLocalPlayer();
		string target_username = params.read_string();//this is the name of the player's head we are truing to recieve
		if(localPlayer is null){
			return;
		}
		else if(localPlayer.getUsername() != target_username){//if the head is not mine (we dont need to recieve the data of our own head), then..
			const string PROP_NAME = PROP_NAME_PREFIX + target_username;//added the prefix so a player cant deliberately fuck up other game textures. ex: "rope"
			ImageData new_head(64,16);//create empty imagedata object to insert data from bitstream
			for(u8 x = 0; x < 64; x++){					
				for(u8 y = 0; y < 16; y++){			
					if(x >= 48){
						new_head.put(x,y, SColor(0x000000));//3rd frame not used, so all of its pixels are transparent and colorless
					}
					else{
						SColor pixel(params.read_u8(),params.read_u8(),params.read_u8(),params.read_u8());//A, R, G, B
						new_head.put(x, y, pixel);//insert the pixel into the imagedata
					}
				}
			}
			if(Texture::exists(PROP_NAME)){//if we have already loaded this head (could happen upon a player reconnecting while the client has not), then..
				Texture::update(PROP_NAME, new_head);//update the current texture to the new one
			}
			else{
				Texture::createFromData(PROP_NAME, new_head);//create the texture from our new data
			}
			CBlob@ local_blob = localPlayer.getBlob();
			if(local_blob !is null) LoadHead(local_blob.getSprite());
		}
	}
}


//handling DLCs

class HeadsDLC {
	string filename;
	bool do_teamcolour;
	bool do_skincolour;

	HeadsDLC(string file, bool team, bool skin) {
		filename = file;
		do_teamcolour = team;
		do_skincolour = skin;
	}
};

const array<HeadsDLC> dlcs = {
	//vanilla
	HeadsDLC("Entities/Characters/Sprites/Heads.png", true, true),
	//flags of the world
	HeadsDLC("Entities/Characters/Sprites/Heads2.png", false, false)
};

const int dlcs_count = dlcs.length;

int get_dlc_number(int headIndex)
{
	if (headIndex > 255) {
		if ((headIndex % 256) > NUM_UNIQUEHEADS) {
			return Maths::Min(dlcs_count - 1, Maths::Floor(headIndex / 255.0f));
		}
	}
	return 0;
}

int getHeadFrame(CBlob@ blob, int headIndex)
{
	if(headIndex < NUM_UNIQUEHEADS)
	{
		return headIndex * NUM_HEADFRAMES;
	}

	if(headIndex == 255 || headIndex == NUM_UNIQUEHEADS)
	{
		CRules@ rules = getRules();
		bool holidayhead = false;
		if(rules !is null && rules.exists("holiday"))
		{
			const string HOLIDAY = rules.get_string("holiday");
			if(HOLIDAY == "Halloween")
			{
				headIndex = NUM_UNIQUEHEADS + 43;
				holidayhead = true;
			}
			else if(HOLIDAY == "Christmas")
			{
				headIndex = NUM_UNIQUEHEADS + 61;
				holidayhead = true;
			}
		}

		//if nothing special set
		if(!holidayhead)
		{
			string config = blob.getConfig();
			if(config == "builder")
			{
				headIndex = NUM_UNIQUEHEADS;
			}
			else if(config == "knight")
			{
				headIndex = NUM_UNIQUEHEADS + 1;
			}
			else if(config == "archer")
			{
				headIndex = NUM_UNIQUEHEADS + 2;
			}
			else if(config == "migrant")
			{
				Random _r(blob.getNetworkID());
				headIndex = 69 + _r.NextRanged(2); //head scarf or old
			}
			else
			{
				// default
				headIndex = NUM_UNIQUEHEADS;
			}
		}
	}

	return (((headIndex - NUM_UNIQUEHEADS / 2) * 2) +
	        (blob.getSexNum() == 0 ? 0 : 1)) * NUM_HEADFRAMES;
}

string getHeadTexture(int headIndex)
{
	return dlcs[get_dlc_number(headIndex)].filename;
}

void onPlayerInfoChanged(CSprite@ this)
{
	
}

CSpriteLayer@ LoadHead(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	if(blob !is null){
		this.RemoveSpriteLayer("head");

		bool custom = false;
		string prop_name;
		CPlayer@ player = blob.getPlayer();
		CPlayer@ localPlayer = getLocalPlayer();
		if(player !is null && localPlayer !is null){
			string username = player.getUsername();
			if(username == localPlayer.getUsername()){//if i am trying to load my own head, then..
				prop_name = HEAD_PROP;
			}
			else{
				prop_name = PROP_NAME_PREFIX + username;				
			}
			custom = Texture::exists(prop_name);//if the texture "exists" then it mean it has already been loaded properly
		}
		// add head
		u16 headIndex = blob.getHeadNum();
		HeadsDLC dlc = dlcs[get_dlc_number(headIndex)];
		CSpriteLayer@ head;
		if(custom){//if we are trying to load a custom head, then...
			@head = this.addTexturedSpriteLayer("head", prop_name, 16, 16);//add a textured sprite layer with the texture we created earlier (either in check_head if it was your own or in the send_head command)
		}
		else{
	    	@head = this.addSpriteLayer("head", dlc.filename, 16, 16,
	                     (dlc.do_teamcolour ? blob.getTeamNum() : 0),
	                     (dlc.do_skincolour ? blob.getSkinNum() : 0));		
	    }

		// set defaults
		headIndex = headIndex % 256; // DLC heads
		s32 headFrame = custom ? 0 : getHeadFrame(blob, headIndex);//all the custom heads textures will only be 3 frames, so this must be 0
		blob.set_s32("head index", headFrame);

		if (head !is null)
		{
			Animation@ anim = head.addAnimation("default", 0, false);
			anim.AddFrame(headFrame);
			anim.AddFrame(headFrame + 1);
			anim.AddFrame(headFrame + 2);
			head.SetAnimation(anim);

			head.SetFacingLeft(blob.isFacingLeft());
		}
		return head;
	}
	return null;
}

//this function checks if the file exists and is the right size..
//if the texture "exists" then it mean it has already been loaded properly
bool check_head(){
	if(Texture::exists(HEAD_PROP)) return true; //did we already load the head?
	else if(Texture::createFromFile(HEAD_PROP, HEAD_PATH)){//if the head is in the right directory...
		ImageData@ head = Texture::data(HEAD_PROP);
		print(" " + head.width() + " " + head.height());
		if(head.width() == 64 && head.height() == 16){//and it is the right size....
			warn(SUCCESS_WARN);
			return true;//then success!
		}
		else{
			warn(WRONG_SIZE_WARN);
			Texture::destroy(HEAD_PROP);//destroy the texture since it was not the right size. 
		}
	}
	else{
		warn(NOT_FOUND_WARN);
	}
	return false;
}

void serialize_image(ImageData@ head, CBitStream@ stream){
	for(u16 x = 0; x < 48; x++){//iterate only through the first 3 frames since the last frame is useless
		for(u16 y = 0; y < 16; y++){
			SColor pixel = head.get(x,y);//get the pixel at the current location
			if(pixel.getAlpha() == 0){//any fully transparent pixels will have 0 for rgb to make compression easier for the server.
				stream.write_u8(0);
				stream.write_u8(0);
				stream.write_u8(0);
				stream.write_u8(0);
			}
			else{//these are written backwards so that it is in order when reading it
				stream.write_u8(pixel.getBlue());
				stream.write_u8(pixel.getGreen());
				stream.write_u8(pixel.getRed());
				stream.write_u8(pixel.getAlpha());
			}
		}
	}
}

void onGib(CSprite@ this)
{
	if (g_kidssafe)
	{
		return;
	}

	CBlob@ blob = this.getBlob();
	if (blob !is null && blob.getName() != "bed")
	{
		int frame = blob.get_s32("head index");
		int framex = frame % FRAMES_WIDTH;
		int framey = frame / FRAMES_WIDTH;

		Vec2f pos = blob.getPosition();
		Vec2f vel = blob.getVelocity();
		f32 hp = Maths::Min(Maths::Abs(blob.getHealth()), 2.0f) + 1.5;
		makeGibParticle(getHeadTexture(blob.getHeadNum()),
		                pos, vel + getRandomVelocity(90, hp , 30),
		                framex, framey, Vec2f(16, 16),
		                2.0f, 20, "/BodyGibFall", blob.getTeamNum());
	}
}

void onTick(CSprite@ this)
{
	CBlob@ blob = this.getBlob();

	ScriptData@ script = this.getCurrentScript();
	if (script is null)
		return;

	if (blob.getShape().isStatic())
	{
		script.tickFrequency = 60;
	}
	else
	{
		script.tickFrequency = 1;
	}


	// head animations
	CSpriteLayer@ head = this.getSpriteLayer("head");

	// load head when player is set or it is AI
	CPlayer@ player = blob.getPlayer();
	if (head is null && (player !is null || (blob.getBrain() !is null && blob.getBrain().isActive()) || blob.getTickSinceCreated() > 3))
	{
		CPlayer@ localPlayer = getLocalPlayer();
		if(getNet().isClient() && localPlayer !is null && player !is null && player.getUsername() == localPlayer.getUsername() && !Texture::exists(localPlayer.getUsername())){//if this is on MY client and i have not yet loaded a custom head, then...
			if(check_head()){//check if the head is there and the right size, then...
	 			CBitStream params;
				params.write_string(localPlayer.getUsername());//so the clients know who the head belongs to
				serialize_image(Texture::data(HEAD_PROP), params);//read the imagedata and write it to the bitstream
		 		blob.SendCommand(blob.getCommandID("send_head"), params);//this sends the bitstream to all the other clients
		 	}
		}
		@head = LoadHead(this);//instantly load our fresh new custom head (this also loads the vanilla heads too)
	}

	if (head !is null)
	{
		Vec2f offset;

		// pixeloffset from script
		// set the head offset and Z value according to the pink/yellow pixels
		int layer = 0;
		Vec2f head_offset = getHeadOffset(blob, -1, layer);

		// behind, in front or not drawn
		if (layer == 0)
		{
			head.SetVisible(false);
		}
		else
		{
			head.SetVisible(this.isVisible());
			head.SetRelativeZ(layer * 0.25f);
		}

		offset = head_offset;

		// set the proper offset
		Vec2f headoffset(this.getFrameWidth() / 2, -this.getFrameHeight() / 2);
		headoffset += this.getOffset();
		headoffset += Vec2f(-offset.x, offset.y);
		headoffset += Vec2f(0, -2);
		head.SetOffset(headoffset);

		if (blob.hasTag("dead") || blob.hasTag("dead head"))
		{
			head.animation.frame = 2;

			// sparkle blood if cut throat
			if (getNet().isClient() && getGameTime() % 2 == 0 && blob.hasTag("cutthroat"))
			{
				Vec2f vel = getRandomVelocity(90.0f, 1.3f * 0.1f * XORRandom(40), 2.0f);
				ParticleBlood(blob.getPosition() + Vec2f(this.isFacingLeft() ? headoffset.x : -headoffset.x, headoffset.y), vel, SColor(255, 126, 0, 0));
				if (XORRandom(100) == 0)
					blob.Untag("cutthroat");
			}
		}
		else if (blob.hasTag("attack head"))
		{
			head.animation.frame = 1;
		}
		else
		{
			head.animation.frame = 0;
		}
	}
}