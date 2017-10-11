// generic character head script

// TODO: fix double includes properly, added the following line temporarily to fix include issues
#include "PaletteSwap.as"
#include "PixelOffsets.as"
#include "RunnerTextures.as"
#include "PlayerHeads.as"

const s32 NUM_HEADFRAMES = 4;
const s32 NUM_UNIQUEHEADS = 30;
const int FRAMES_WIDTH = 8 * NUM_HEADFRAMES;

//handling DLCs
void onInit(CBlob@ this){
	this.set_string("username", "");
	CRules@ rules = getRules();
	if(getNet().isServer() && !getNet().isClient() && !rules.get_bool(ADDED_SCRIPT_PREFIX) || !rules.exists(ADDED_SCRIPT_PREFIX)){
		print("initialized headhandler");
		rules.addCommandID("send_head");
		rules.addCommandID("sync_head");
		rules.AddScript(RULES_SCRIPT_PATH);
		PlayerHead@[] heads;
		rules.set("playerheads", heads);
		rules.set_bool(ADDED_SCRIPT_PREFIX, true);
	}
}

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
		if(player !is null){
			string username = player.getUsername();
			blob.set_string("username", username);//used for gibs after the player is null
			prop_name = PROP_NAME_PREFIX + username;	
			custom = Texture::exists(prop_name);//if the texture "exists" then it mean it has already been loaded properly
		}
		// add head
		u16 headIndex = blob.getHeadNum();
		HeadsDLC dlc = dlcs[get_dlc_number(headIndex)];
		CSpriteLayer@ head;
		if(custom){//if we are trying to load a custom head, then...
			//this next section just tries to change the head color based on the team using the TeamPallete.png
			const string team_head_prop = TEAM_HEAD_PREFIX + prop_name;
			if(!Texture::createFromCopy(team_head_prop, prop_name)) Texture::update(team_head_prop, Texture::data(prop_name));
			changeHeadColor(prop_name, team_head_prop, blob.getTeamNum());
			@head = this.addTexturedSpriteLayer("head", team_head_prop, 16, 16);//add a textured sprite layer with the texture we created earlier (either in check_head if it was your own or in the send_head command)
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
bool check_head(string prop_name){
	if(Texture::exists(prop_name)) return true; //did we already load the head?
	else if(CFileMatcher("head.png").getFirst() == HEAD_PATH && Texture::createFromFile(prop_name, HEAD_PATH)){//if the head is in the right directory...
		ImageData@ head = Texture::data(prop_name);
		if(head.width() == 64 && head.height() == 16){//and it is the right size....
			warn(SUCCESS_WARN);
			return true;//then success!
		}
		else{
			warn(WRONG_SIZE_WARN);
			Texture::destroy(prop_name);//destroy the texture since it was not the right size. 
		}
	}
	else{
		warn(NOT_FOUND_WARN);
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

		bool custom = false;
		string prop_name;
		string username = blob.get_string("username");
		if(username != ""){
			prop_name = PROP_NAME_PREFIX + username;	
			custom = Texture::exists(prop_name);//if the texture "exists" then it mean it has already been loaded properly
		}
		if(custom){
			const string particle_prop_name = PARTICLE_PREFIX + prop_name;
			if(!Texture::createFromCopy(particle_prop_name, prop_name)) Texture::update(particle_prop_name, Texture::data(prop_name));
			changeHeadColor(prop_name, particle_prop_name, blob.getTeamNum());
			ParticleTexturedGibs(particle_prop_name, 
				pos,  vel + getRandomVelocity(90, hp , 30), 
				framex, framey, "/BodyGibFall", 
				2.0f, 20, Vec2f(16, 16));
		}
		else{
			makeGibParticle(getHeadTexture(blob.getHeadNum()),
                pos, vel + getRandomVelocity(90, hp , 30),
                framex, framey, Vec2f(16, 16),
                2.0f, 20, "/BodyGibFall", blob.getTeamNum());
		}	
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
		
		if(getNet().isClient() && localPlayer !is null && player !is null && player.getUsername() == localPlayer.getUsername()){//if this is on MY client, then..
			CRules@ rules = getRules();
			const string username = player.getUsername();
			const string SENT_HEAD_PROP = SENT_HEAD_PREFIX + username;
			if(!rules.get_bool(SENT_HEAD_PROP)){
				const string HEAD_PROP_NAME = PROP_NAME_PREFIX + username;
				const string ADDED_SCRIPT_PROP = ADDED_SCRIPT_PREFIX + username;
				if(!rules.get_bool(ADDED_SCRIPT_PROP) || !rules.exists(ADDED_SCRIPT_PROP)){
					print("adding command ids on client");
					rules.addCommandID("send_head");
					rules.addCommandID("sync_head");
					rules.AddScript(RULES_SCRIPT_PATH);
					PlayerHead@[] heads;
					rules.set("playerheads", heads);
					CBitStream params;
					params.write_string(username);
					rules.set_bool(ADDED_SCRIPT_PREFIX + username, true);
					rules.SendCommand(rules.getCommandID("send_head"),params);//this doesnt actually send a head it just tells the server that we have added the command ids and scripts that we need, so that it can sync all the heads to us later.
				}
				if(rules.get_bool(ADDED_SCRIPT_PROP) && check_head(HEAD_PROP_NAME)){//check if the head is there and the right size, then...
		 			rules.set_bool(SENT_HEAD_PROP, true);
		 			CBitStream params;
					params.write_string(username);//so the clients know who the head belongs to
					CBitStream image_stream;
					serialize_image(Texture::data(HEAD_PROP_NAME), image_stream);//read the imagedata and write it to the bitstream
					params.write_CBitStream(image_stream);
			 		getRules().SendCommand(rules.getCommandID("send_head"), params);//this sends the bitstream to all the other clients
			 		print("sent send_head cmd");
			 	}
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