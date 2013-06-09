__module_name__ = 'Russian Roulette'
__module_version__ = '1.0'
__module_description__ = 'Russian Roulette'

import xchat
from random import choice, randint

triggers = ("#roulette", "#r")
actions = ("challenge", "challenge_reset", "help")
guns = {} # This will hold all instances of the Gun class
start_messages = ("%(nick)s spins the barrel...",)
wait_messages = ("%(nick)s, you can't fire twice in a row.",)
fire_messages = ("%(nick)s pulls the trigger.",)
life_messages = ("The gun clicks.", "Silence.", "The gun jams.",
                 "%(nick)s lives to see another day.",
                 "The chamber is empty.",)
death_messages = ("BANG!", "The bullet rips through %(nick)s's skull.",
                 "%(nick)s's body hits the ground with a heavy thud.",
                 "A blinding light is the last thing %(nick)s sees.",
                 "Blood splatters everywhere.",)
help_messages = ("Usage:  * Help: #r help",
                 "        * FreeForAll Game: #r",
                 ("        * Start Challenge: #r challenge <nick> [nick] ..."),
                 "        * Continue Challenge: #r challenge",
                 "        * Reset Challenge: #r challenge_reset")


class Gun:
    """ Each game is represented by a Gun class instance. """
    def __init__(self, channel, challenger=None, challenged=None):
        """ Initialize Gun, including challenge info if applicable """
        self.bullets_max = 6
        self.bullets = self.bullets_max
        self.last_user = None
        self.channel = channel
        self.challenger = challenger
        self.challenged = challenged
        if challenger:
            self.append_text = "".join(["[", challenger, " vs ",
                                        ' vs '.join(challenged), "]"])
        else:
            self.append_text = "[FreeForAll - %s]" % self.channel

    def trigger(self, user):
        """ Triggers the gun.
        Returns True if the gun fires, False otherwise.
        
        """
        msg = ""
        msg = ''.join([self.append_text, " - "])
        # First round in this game - include a start message.
        if not self.last_user:
            msg = ''.join([msg, choice(start_messages), " "])
        # Fires the gun. Repetitive firing is not allowed.
        if user != self.last_user:
            self.last_user = user
            msg = ''.join([msg, choice(fire_messages), " "])
            send_message(self.channel, user, msg)
            if randint(1, self.bullets) == 1:
                msg = ''.join(["\00304", choice(death_messages)])
                send_message(self.channel, user, msg)
                return True
            else:
                msg = ''.join(["\00302", choice(life_messages)])
                send_message(self.channel, user, msg)
            self.bullets -= 1
        # User is trying to fire twice in a row.
        else:
            send_message(self.channel, user, choice(wait_messages))
        return False


def send_message(channel, user, data):
    """ Sends the message to the channel. Performs some substitutions. """
    data = data % {'nick': user}
    xchat.command('msg ' + channel + ' \00307' + data)

def challenge(channel, user, args):
    """ Challenge mode.
    
    If arguments are passed, checks if the user is already in a challenge.
    If not, one is created.
    If no arguments are passed, plays the next round of the challenge, if it
    exists.
    
    """
    if args and user in guns:
        send_message(channel, user, ("You're already in a challenge, %(nick)s."
                                     " To pull the trigger, type: "
                                     "'#r challenge'."))
    elif args:
        guns[user] = Gun(channel, user, args)
        # After creating guns[user], also point the challenged persons' guns to
        # it, by setting guns[challenged] to the user's nickname.
        # This links all persons in the same challenge together.
        for challenged in args:
            guns[challenged] = user
        send_message(channel, user, ''.join([("%(nick)s started a new"
                                              " challenge with... "),
                                              ', '.join(args), "!",
                                              (" '#r challenge' pulls the"
                                              " trigger!")]))
    else:
        # User is already in a challenge.
        if user in guns:
            # The user isn't the creator of the challenge, but guns[user]
            # contains the name of the creator.
            # We'll therefore use guns[guns[user]], where the info for this
            # challenge is actually stored.
            if isinstance(guns[user], basestring):
                if guns[guns[user]].trigger(user):
                    clean_guns(guns[user]) # del guns pointing to this one.
                    send_message(channel, user, ("Challenge over!"))
            # The user is the creator of the challenge - continue normally.
            else:
                if guns[user].trigger(user):
                    clean_guns(user) # del guns pointing to this one.
                    send_message(channel, user, ("Challenge over!"))
        # User hasn't joined any challenge.
        else:
            send_message(channel, user, ("You're not in any challenge,"
                                         " %(nick)s. To challenge someone,"
                                         " type '#r challenge <nick> [nick]"
                                         " ...'"))

def challenge_reset(user):
    """ Clears the user's challenges. """
    if user in guns:
        clean_guns(user)
        return "Challenge reset, %(nick)s,"
    else:
        return "You're not challenging anyone, %(nick)s."

def ffa(user, channel):
    """ Free for all game.
    
    Create a game if it doesn't exist already, then fire the gun.
    
    """
    if not channel in guns:
        guns[channel] = Gun(channel)
    if guns[channel].trigger(user):
        del guns[channel]

def get_args(word):
    """ Extracts arguments from the message.
    
    Returns: The calling user, the specified action and extra args
    
    """
    user = xchat.strip(word[0])
    try:
        action = xchat.strip(word[1].split(' ', 2)[1])
    except IndexError:
        action = None
    try:
        args = word[1].strip().split(' ', 2)[2].split(' ')
        args = [xchat.strip(v) for v in args]
    except IndexError:
        args = None
    return user, action, args

def handler(word, word_eol, userdata):
    """ Handles the different commands. """
    channel = xchat.get_info('channel')
    command = xchat.strip(word[1].split(' ', 1)[0])
    if command in triggers:
        user, action, args = get_args(word)
        if not action:
            ffa(user, channel)
        elif action in actions:
            if action == actions[0]: # challenge
                challenge(channel, user, args)
            elif action == actions[1]: # challenge_reset
                send_message(channel, user, challenge_reset(user))
            elif action == actions[2]: # help
                for msg in help_messages:
                    send_message(channel, user, msg)

def clean_guns(user):
    """ When a challenge is created by user, challenged persons' guns only
    contain a string: the name of the creator. This removes all guns pointing
    to the creator (user), as well as the user's gun itself, thus clearing the
    challenge completely.
    
    """
    del guns[user]
    for key in guns.keys():
        if isinstance(guns[key], basestring) and guns[key] == user:
            del guns[key]


xchat.hook_print('Channel Msg Hilight', handler)
xchat.hook_print('Channel Message', handler)
xchat.hook_print('Your Message', handler)

print "\00304%s successfully loaded." % __module_name__
