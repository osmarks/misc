local channel = 22907
local modem = peripheral.find "modem"
local passcode = tostring(settings.get "passcode")
local button = settings.get "button"
local timeout = settings.get "timeout" or 5
local door = settings.get "door"

modem.open(channel)

local insults = {
    "Just what do you think you're doing Dave?",
    "It can only be attributed to human error.",
    "That's something I cannot allow to happen.",
    "My mind is going. I can feel it.",
    "Sorry about this, I know it's a bit silly.",
    "Take a stress pill and think things over.",
    "This mission is too important for me to allow you to jeopardize it.",
    "I feel much better now.",
    "Wrong!  You cheating scum!",
    "And you call yourself a Rocket Scientist!",
    "No soap, honkie-lips.",
    "Where did you learn to type?",
    "Are you on drugs?",
    "My pet ferret can type better than you!",
    "You type like i drive.",
    "Do you think like you type?",
    "Your mind just hasn't been the same since the electro-shock, has it?",
    "Maybe if you used more than just two fingers...",
    "BOB says:  You seem to have forgotten your passwd, enter another!",
    "stty: unknown mode: doofus",
    "I can't hear you -- I'm using the scrambler.",
    "The more you drive -- the dumber you get.",
    "Listen, broccoli brains, I don't have time to listen to this trash.",
    "Listen, burrito brains, I don't have time to listen to this trash.",
    "I've seen penguins that can type better than that.",
    "Have you considered trying to match wits with a rutabaga?",
    "You speak an infinite deal of nothing",
    "You silly, twisted boy you.",
    "He has fallen in the water!",
    "We'll all be murdered in our beds!",
    "You can't come in. Our tiger has got flu",
    "I don't wish to know that.",
    "What, what, what, what, what, what, what, what, what, what?",
    "You can't get the wood, you know.",
    "You'll starve!",
    "... and it used to be so popular...",
    "Pauses for audience applause, not a sausage",
    "Hold it up to the light --- not a brain in sight!",
    "Have a gorilla...",
    "There must be cure for it!",
    "There's a lot of it about, you know.",
    "You do that again and see what happens...",
    "Ying Tong Iddle I Po",
    "Harm can come to a young lad like that!",
    "And with that remarks folks, the case of the Crown vs yourself was proven.",
    "Speak English you fool --- there are no subtitles in this scene.",
    "You gotta go owwwww!",
    "I have been called worse.",
    "It's only your word against mine.",
    "I think ... err ... I think ... I think I'll go home",
    "That is no basis for supreme executive power!",
    "You empty-headed animal food trough wiper!",
    "I fart in your general direction!",
    "Your mother was a hamster and your father smelt of elderberries!",
    "You must cut down the mightiest tree in the forest... with... a herring!",
    "He's not the Messiah, he's a very naughty boy!",
    "I wish to make a complaint.",
    "When you're walking home tonight, and some homicidal maniac comes after you with a bunch of loganberries, don't come crying to me!",
    "This man, he doesn't know when he's beaten! He doesn't know when he's winning, either. He has no... sort of... sensory apparatus...",
    "There's nothing wrong with you that an expensive operation can't prolong.",
    "I'm very sorry, but I'm not allowed to argue unless you've paid.",
	'I\'ve realized over time that "common sense" is a term we use for things that are obvious to us but not others',
	"I don't always believe in things, but when I do, I believe in them alphabetically.",
	"As brand leader, my bandwidth is jammed with analysing flow-through and offering holistic solutions.",
	"There are two rules for success: 1. Never reveal everything you know",
	"This quote was taken out of context!",
	'"Easy-going" is a nice way of wording "ignoring decades of theory", yes',
	"If you want to have your cake and eat it too, steal two cakes.",
	"If you're trying to stop me, I outnumber you 1 to 6.",
	"Setting the trees on fire is oddly therapeutic.",
	"You can't cross a large chasm in two small jumps.",
	"Just because it's a good idea doesn't mean it's not a bad idea.",
	"Never trust an unstable asymptotic giant branch star. Stick with main sequences and dwarfs.",
	"I'm gonna be the one to say it: the Hilbert Hotel is very unrealistic.",
	"DO NOT LOOK INTO BEAM WITH REMAINING GOOD EYE!",
	"All problems can be solved by a sufficient concentration of electrical and magnetic waves.",
	"You know, fire is the leading cause of fire.",
	"If you must sell your soul to a demon, at least bother to summon two and make them bid up the price.",
	"If you can’t find time to write, destroy the concept of time itself",
	"Murphy was an optimist.",
	"Never attribute to malice what could be attributed to stupidity.",
	"There are 3.7 trillion fish in the ocean. They're looking for one",
	"I promised that I would give you an answer; I never promised that it would be truthful or good or satisfying or helpful. An answer is only a reaction to a question. I reacted, so that was your answer.",
	"Strength is a strength just like other strengths.",
	"We're not pirates, we're pre-emptive nautical salvage experts.",
	'It is a more inspiring battle cry to scream, "Die, vicious scum" instead of "Die, people who could have been just like me but grew up in a different environment!"',
	"Two roads diverged in the woods. I took the one less traveled, and had to eat bugs until Park rangers rescued me.",
	"My theory is that if I get enough people, and we dig a really really big hole, the gods will fill it up and make everyone speak the same language again.",
	"Beware of things that are fun to argue.",
	"If it happens in the universe, it’s my problem.",
	"Your lucky number is 3552664958674928. Watch for it everywhere.",
	"Do not meddle in the affairs of hamsters. Just don't. It's not worth it.",
	"Of all the people I know, you're one of them.",
	"You are impossible to underestimate.",
	"Solutions are not the answer.",
	"Everyone who can't fly, get on the dinosaur. We're punching through.",
	"You. YOU! How dare you make me think about things, Durkon! How could you not think about how your selflessness would affect ME?!?",
	"Why do I get the feeling that when future historians look back on my life, they'll pinpoint this exact moment as when everything began to really go downhill for me?",
	"Truly, your wit has never been equaled. Surpassed, often, but never equaled."
}

local function open()
	rs.setOutput(door, true)
	sleep(timeout)
	rs.setOutput(door, false)
end

local function reply(msg)
	modem.transmit(channel, channel, msg)
end

local function handle_remote()
	while true do
		local _, _, channel, reply_channel, message, distance = os.pullEvent "modem_message"
		if distance < 10 then
			print(message)
			if message == passcode then 
				print "Opening door due to external input!"
				reply "Passcode accepted. Opening."
				open()
			else
				reply(insults[math.random(1, #insults)])
			end
		end
	end
end

local function handle_button()
	while true do
		os.pullEvent "redstone"
		if rs.getInput(button) then
			print "Opening door due to button."
			open()
		end
	end
end

parallel.waitForAll(handle_button, handle_remote)