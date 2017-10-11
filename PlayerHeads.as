//these are just some constants
const string ADDED_SCRIPT_PREFIX = "added script: ";
const string GOT_SYNC_PREFIX = "got sync: ";
const string SENT_HEAD_PREFIX = "sent head: ";
const string PROP_NAME_PREFIX = "head: ";
const string TEAM_HEAD_PREFIX = "teamhead: ";
const string PARTICLE_PREFIX = "particle: ";
const string HEAD_PATH = "Maps/head.png";
const string RULES_SCRIPT_PATH = "../Mods/PlayerHeads/HeadHandler.as";
const string SUCCESS_WARN = "Your head was successfully loaded.";
const string NOT_FOUND_WARN = "No head was found in " + HEAD_PATH + ". To get a custom head, you must put it in this directory. For more help, visit the forums.";
const string WRONG_SIZE_WARN = "Your head must be 64 x 16. Please check your head in " + HEAD_PATH;

class PlayerHead{
	string username;
	CBitStream image_stream;
	PlayerHead(string username_, CBitStream@ image_stream_){
		username = username_;
		image_stream = image_stream_;
	}
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
			else{//write each value to the stream
				stream.write_u8(pixel.getAlpha());
				stream.write_u8(pixel.getRed());
				stream.write_u8(pixel.getGreen());
				stream.write_u8(pixel.getBlue());
			}
		}
	}
}

ImageData@ deserialize_image(CBitStream@ image_stream){
	ImageData new_head(64,16);//create empty imagedata object to insert data from bitstream
	for(u8 x = 0; x < 64; x++){					
		for(u8 y = 0; y < 16; y++){			
			if(x >= 48){
				new_head.put(x,y, SColor(0x000000));//3rd frame not used, so all of its pixels are transparent and colorless
			}
			else{
				u8 a = image_stream.read_u8();
				u8 r = image_stream.read_u8();
				u8 g = image_stream.read_u8();
				u8 b = image_stream.read_u8();
				SColor pixel(a,r,g,b);
				new_head.put(x, y, pixel);//insert the pixel into the imagedata
			}
		}
	}
	return new_head;
}

//gets data from the input_prop_name and applies the team color onto output_prop_name 
void changeHeadColor(string input_prop_name, string output_prop_name, int team){
	print("changeHeadColor: " + input_prop_name + " " + output_prop_name + " " + team);
	const string pallete = "pallette__";
	if(!Texture::exists(pallete)) Texture::createFromFile(pallete, "TeamPalette.png");
	if(!UpdatePaletteSwappedTexture(Texture::data(input_prop_name), output_prop_name, Texture::data(pallete), team)){
		print("error creating pallete swapped tex, report this");
	}
}

//stole from palleteswap to allow functionality for updatin existing textures
bool UpdatePaletteSwappedTexture(ImageData@ input, string output_name, ImageData@ palette, int palette_index)
{
	//not needed on server or something went wrong with getting imagedata
	if(!getNet().isClient() || palette is null || input is null || !Texture::exists(output_name)) return false; 
	if(palette_index == 0) return true;
		
	//read out the relevant palette colours
	array<SColor> in_colours;
	array<SColor> out_colours;
	for(int i = 0; i < palette.height(); i++)
	{
		in_colours.push_back(palette.get(0, i));
		out_colours.push_back(palette.get(palette_index, i));
	}

	ImageData@ edit = input;

	if(edit is null)
	{
		Texture::destroy(output_name);
		return false;
	}

	for(int i = 0; i < edit.size(); i++)
	{
		SColor c = edit[i];

		//skip trasparent pixels
		if(c.getAlpha() == 0) continue;

		//search the pixels array and recolour
		for(int p = 0; p < in_colours.length; p++)
		{
			SColor inp = in_colours[p];
			SColor oup = out_colours[p];
			if(c.getRed() == inp.getRed() &&
				c.getGreen() == inp.getGreen() &&
				c.getBlue() == inp.getBlue())
			{
				c.setRed(oup.getRed());
				c.setGreen(oup.getGreen());
				c.setBlue(oup.getBlue());
			}
		}
		edit[i] = c;
	}

	if(!Texture::update(output_name, edit))
	{
		Texture::destroy(output_name);
		return false;
	}

	return true;
}