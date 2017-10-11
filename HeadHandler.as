#include "PlayerHeads.as";

string[] particle_textures_to_delete;
u32[] delete_times;

void onCommand(CRules@ this, u8 cmd, CBitStream@ params){
	if(getNet().isServer() && cmd == this.getCommandID("send_head")){
		string username = params.read_string();
		this.set_bool(ADDED_SCRIPT_PREFIX + username, true);//this lets the server know we are ready to for the server to send us all the other players' heads
		print("ADDED_SCRIPT_PREFIX + username is true on server");
		CBitStream image_stream;
		PlayerHead@[]@ heads;
		if(params.saferead_CBitStream(image_stream) && this.get("playerheads", @heads)){
			image_stream.ResetBitIndex();
			heads.push_back(PlayerHead(username, image_stream));//store the head data on server, so it can be given to the new players who join
			CBitStream stream;
			stream.write_string(username);//send the name of the player's head we are trying to send
			stream.write_CBitStream(image_stream);//the head data we are sending
			this.SendCommand(this.getCommandID("sync_head"), stream);
			print("sent sync_head cmd for " + username);
		}
	}
	if(getNet().isClient() && cmd == this.getCommandID("sync_head")){
		string username = params.read_string();//this is the name of the player's head we are trying to recieve
		const string PROP_NAME = PROP_NAME_PREFIX + username;//added the prefix so a player cant deliberately fuck up other game textures. ex: "rope"
		if(!Texture::exists(PROP_NAME)){//if the client does not have a head of this player
			CBitStream image_stream;
			if(params.saferead_CBitStream(image_stream)){
				image_stream.Reset();
				print("got sync cmd for " + username);
				Texture::createFromData(PROP_NAME, deserialize_image(image_stream));//create the texture from our new data
				//attempt to reload the player's head so that we can see the new head without waiting for them to die.
				CPlayer@ player = getPlayerByUsername(username);
				if(player !is null){
					CBlob@ blob = player.getBlob();
					if(blob !is null){
						CSprite@ sprite = blob.getSprite();
						if(sprite !is null){
							//this is basically a compacted LoadHead function from runnerhead.as
							CSpriteLayer@ head = sprite.getSpriteLayer("head");
							sprite.RemoveSpriteLayer("head");
							const string team_head_prop = TEAM_HEAD_PREFIX + PROP_NAME;
							Texture::createFromCopy(team_head_prop, PROP_NAME);
							changeHeadColor(PROP_NAME, team_head_prop, blob.getTeamNum());
							@head = sprite.addTexturedSpriteLayer("head", team_head_prop, 16, 16);
							blob.set_s32("head index",0);
							Animation@ anim = head.addAnimation("default", 0, false);
							anim.AddFrame(0);
							anim.AddFrame(1);
							anim.AddFrame(2);
							head.SetAnimation(anim);
							head.SetFacingLeft(blob.isFacingLeft());
						}
					}
				}
			}
			else{
				print("got sync cmd for " + username + ", but it failed to read the bitstream");
			}
		}
		else{
			//print("got sync cmd, but i already have " + username + "'s head");
		}
	}
}

//here we are removing the leaving player's head from the server so that it will detect a new one if the player rejoins
void onPlayerLeave( CRules@ this, CPlayer@ player ){
	if(getNet().isServer()){
		PlayerHead@[]@ heads;
		if(this.get("playerheads", @heads)){
			for(u8 i = 0; i < heads.length; i++){
				PlayerHead@ head = heads[i];
				if(head.username == player.getUsername()){
					heads.removeAt(i);
					print("server removed " + head.username + " head");
					break;
				}
			}
		}
	}
	if(getNet().isClient()){
		Texture::destroy(PROP_NAME_PREFIX + player.getUsername());//this destorys the texture of the leaving player's head so that when they rejoin the clients are ready to accept a new one
		Texture::destroy(TEAM_HEAD_PREFIX + PROP_NAME_PREFIX + player.getUsername());//this just destroys the copy of the head used to change team colors
		particle_textures_to_delete.push_back(player.getUsername());
		delete_times.push_back(getGameTime() + 10*getTicksASecond());
		print("client destroy " + player.getUsername() + " head");
	}
	const string ADDED_SCRIPT_PROP = ADDED_SCRIPT_PREFIX + player.getUsername();
	const string GOT_SYNC_PROP = GOT_SYNC_PREFIX + player.getUsername();
	this.set_bool(ADDED_SCRIPT_PROP, false);
	this.set_bool(GOT_SYNC_PROP, false);
}

//this code is to sync the heads to the client ONLY when the client has added the rules script and the proper command ids
void onTick(CRules@ this){
	if(getNet().isServer()){
		PlayerHead@[]@ heads;
		if(this.get("playerheads", @heads)){
			for(u8 i = 0; i < getPlayerCount(); i++){
				CPlayer@ player = getPlayer(i);
				const string ADDED_SCRIPT_PROP = ADDED_SCRIPT_PREFIX + player.getUsername();
				const string GOT_SYNC_PROP = GOT_SYNC_PREFIX + player.getUsername();
				if(this.get_bool(ADDED_SCRIPT_PROP) && !this.get_bool(GOT_SYNC_PROP)){//here we check if the player has already added the scripts but not yet gotten the sync
					for(u8 j = 0; j < heads.length; j++){
						PlayerHead@ head = heads[j];
						CBitStream params;
						params.write_string(head.username);
						params.write_CBitStream(head.image_stream);
						this.SendCommand(this.getCommandID("sync_head"), params);
					}
					this.set_bool(GOT_SYNC_PROP, true);//once every sync has been sent out we set this to true so the server doesnt keep trying to send them out anymore
					print("got sync prop truee");
				}
			}
		}
	}
	if(getNet().isClient()){//this part just deletes the particle texture copy that is kept on the server a little longer because of particles that might still be holding the texture.
		for(int i = 0; i < particle_textures_to_delete.length; i++){
			string username = particle_textures_to_delete[i];
			u32 delete_at = delete_times[i];
			if(getGameTime() >= delete_at){
				if(getPlayerByUsername(username) is null){
					Texture::destroy(PARTICLE_PREFIX + PROP_NAME_PREFIX + username);
				}
				particle_textures_to_delete.removeAt(i);
				delete_times.removeAt(i);
				i--;
			}
		}
	}
}