// generic character head script

// TODO: fix double includes properly, added the following line temporarily to fix include issues
#include "PaletteSwap.as"
#include "PixelOffsets.as"
#include "RunnerTextures.as"

const s32 NUM_HEADFRAMES = 4;
const s32 NUM_UNIQUEHEADS = 30;
const int FRAMES_WIDTH = 8 * NUM_HEADFRAMES;
bool loaded_head = false;


void onInit(CBlob@ this)
{
	this.addCommandID("send_head");
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params){
	if(getNet().isClient() && cmd == this.getCommandID("send_head")){
		CPlayer@ localPlayer = getLocalPlayer();
		string target = params.read_string();	
		if(localPlayer is null){
			return;
		}
		else if(localPlayer.getUsername() != target){//read in image data from bitstream
			string path = "Maps/Heads/"+target+".png";
			if(!checkHead(path)){
				CFileImage img(64,16, true);
				img.setFilename(path, ImageFileBase(3));//changing 3 to 1 will make it store stuff in ../Cache but there is no way to load a texture from there
				for(u8 x = 0; x < 64; x++){					//the reason it is stored in maps right now is because 
					for(u8 y = 0; y < 16; y++){				//textures wont load with AddSpriteLayer without the textures first being there upon launching the game
						img.setPixelPosition(Vec2f(x,y));	//since Maps directory is the only one where images wont get deleted on restart, it is currently the only one that works
															//the issue with this is that there is no way to get someone's new head without manually deleting their old one first
															//i am hoping someone else will find a solution to this issue.
						if(x >= 48){//this is because the 4th frame is not used.
							img.setPixel(0,0,0,0);
						}
						else{
							img.setPixel(params.read_u8(),params.read_u8(),params.read_u8(),params.read_u8());//A, R, G, B
						}
					}
				}
				img.Save();
				LoadHead(this.getSprite());
			}
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
		string path;
		CPlayer@ player = blob.getPlayer();
		CPlayer@ localPlayer = getLocalPlayer();
		if(player !is null && localPlayer !is null){
			string username = player.getUsername();
			if(username == localPlayer.getUsername()){
				path = "Maps/myhead.png";//client's head is stored here.
			}
			else{
				path = "Maps/Heads/"+username+".png";
			}
			custom = checkHead(path);
		}
		// add head
		u16 headIndex = blob.getHeadNum();
		HeadsDLC dlc = dlcs[get_dlc_number(headIndex)];
		CSpriteLayer@ head = this.addSpriteLayer("head",
							 custom ? path : dlc.filename, 16, 16,
		                     (dlc.do_teamcolour || custom ? blob.getTeamNum() : 0),
		                     (dlc.do_skincolour || custom ? blob.getSkinNum() : 0));

		// set defaults
		headIndex = headIndex % 256; // DLC heads
		s32 headFrame = custom ? 0 : getHeadFrame(blob, headIndex);

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
bool checkHead(string path){
	CFileImage image(path);
	if(image.width() == 64 && image.height() == 16){
		return true;
	}
	return false;
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
		if(	getNet().isClient() && localPlayer !is null && player !is null && player.getUsername() == localPlayer.getUsername()){//here is where we attempt to load in the client's custom head and then send it to all the other clients.
																				 												 //with this current implementation you should be able to modify your head and send it to other clients in between deaths 
																																 //(which is kinda cool but annoying. but doesnt do that yet until there is a way to reload textures)
																																 // i havent experimented with ReloadSprite function yet so that is a good place to start
			if(checkHead("myhead.png")){
				loaded_head = true;
		 		CBitStream params;
				params.write_string(player.getUsername());
				for(u16 x = 0; x < 48; x++){//iterate only through the first 3 frames
					for(u16 y = 0; y < 16; y++){
						image.setPixelPosition(Vec2f(x,y));
						SColor pixel = image.readPixel();
						if(pixel.getAlpha() == 0){
							params.write_u8(0);
							params.write_u8(0);
							params.write_u8(0);
							params.write_u8(0);
						}
						else{
							params.write_u8(pixel.getBlue());
							params.write_u8(pixel.getGreen());
							params.write_u8(pixel.getRed());
							params.write_u8(pixel.getAlpha());
						}
					}
				}
		 		blob.SendCommand(blob.getCommandID("send_head"), params);
		 		print("sent send_head cmd");
		 	}
		}
		@head = LoadHead(this);
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
