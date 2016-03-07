# Dissecting a Unicorn, writing my first keygen.

The last couple of days I’ve spent my free time doing something a little more adventurous than reading up on Swift or some cool new libraries. I’ve been following the iOS/OSX security site http://reverse.put.as and this top button Crackmes has been looking at me for way too long. Going over the list of files I stumbled upon this application called [Unicorn](https://reverse.put.as/wp-content/uploads/2010/05/2-Unicorn.zip). 
A dear friend told me never to let go of a Unicorn if you find one so the target was set.

So here I am staring the Unicorn straight in the eye, he knows it’s on at this point. But where do I start? I had to do some security research on iOS apps in the past where I used [class-dump](http://stevenygard.com/projects/class-dump/) to get insights in the projects internals, after that I could hook methods with [Theos](http://iphonedevwiki.net/index.php/Theos) so I could make the app do what I want.
So let’s give class dump a try, and see if we find anything interesting here.

```bash
class-dump -A /Users/cedrick/Desktop/hex/Unicorn.app

@interface UnicornAppDelegate : NSObject
{
    NSWindow *window;
    NSTextField *nameField;
    NSTextField *serialField;
}

- (void)applicationDidFinishLaunching:(id)arg1;    // IMP=0x00002a23
- (void)awakeFromNib;    // IMP=0x00002ac1
- (void)validate:(id)arg1;    // IMP=0x00002af0
- (_Bool)validateSerial:(id)arg1 forName:(id)arg2;    // IMP=0x00002a41
- (id)window;    // IMP=0x00002a28
- (void)setWindow:(id)arg1;    // IMP=0x00002a33

@end

@interface NSData (CocoaCryptoHashing)
- (id)md5HexHash;    // IMP=0x00002be1
@end

@interface NSString (CocoaCryptoHashing)
- (id)md5HexHash;    // IMP=0x00002ba5
@end
```
From this small snippet we can pretty much guess what’s going on here; the validate function is invoked on a button click (taking the button as arg1), this uses the contents of the name & serial fields and passes this to the validateSerial:forName: method. Somewhere in this method something is converted to an MD5 Hex Hash. But at this point this is merely speculation. If I this was an iOS app that I had to research I would probably hook this method and make it simply return YES all the time. We've got our point of attack, but how do we attack it? 

As we’re trying to learn something new lets try to actually reverse the algorithm instead of 'simply' patching the method to always retrun YES. We need to take a look under the hood, lets fire up lldb and see if we can get the internals.
```bash
Cedricks-iMac:~ cedrick$ lldb /Users/cedrick/Desktop/hex/Unicorn.app
(lldb) target create "/Users/cedrick/Desktop/hex/Unicorn.app"
Segmentation fault: 11
```
This is not a good sign… Let’s try attach instead
```bash
Cedricks-iMac:~ cedrick$ ps aux | grep Unicorn
cedrick           896   0.0  0.0  2461036    556 s000  U+    8:45AM   0:00.00 grep Unicorn
cedrick           894   0.0  0.1   716708  21496   ??  U     8:45AM   0:00.20 /Users/cedrick/Desktop/hex/Unicorn.app/Contents/MacOS/Unicorn

(lldb) attach 894
Process 894 stopped...
```
Success! Now let’s dissect this beast:
```bash
(lldb) disas -n "-[UnicornAppDelegate validateSerial:forName:]"
Unicorn`-[UnicornAppDelegate validateSerial:forName:]:
    0x2a41 <+0>:   pushl  %ebp
    0x2a42 <+1>:   movl   %esp, %ebp
    0x2a44 <+3>:   subl   $0x18, %esp
    0x2a47 <+6>:   movl   $0x3044, 0x8(%esp)
    0x2a4f <+14>:  movl   0x4010, %eax
    0x2a54 <+19>:  movl   %eax, 0x4(%esp)
    0x2a58 <+23>:  movl   0x14(%ebp), %eax
    0x2a5b <+26>:  movl   %eax, (%esp)
    0x2a5e <+29>:  calll  0x2cd2                    ; symbol stub for: objc_msgSend
    0x2a63 <+34>:  movl   0x400c, %edx
    0x2a69 <+40>:  movl   %edx, 0x4(%esp)
    0x2a6d <+44>:  movl   %eax, (%esp)
    0x2a70 <+47>:  calll  0x2cd2                    ; symbol stub for: objc_msgSend
    0x2a75 <+52>:  movl   0x4008, %edx
    0x2a7b <+58>:  movl   %edx, 0x4(%esp)
    0x2a7f <+62>:  movl   %eax, (%esp)
    0x2a82 <+65>:  calll  0x2cd2                    ; symbol stub for: objc_msgSend
    0x2a87 <+70>:  movl   $0x14, 0x8(%esp)
    0x2a8f <+78>:  movl   0x4004, %edx
    0x2a95 <+84>:  movl   %edx, 0x4(%esp)
    0x2a99 <+88>:  movl   %eax, (%esp)
    0x2a9c <+91>:  calll  0x2cd2                    ; symbol stub for: objc_msgSend
    0x2aa1 <+96>:  movl   0x10(%ebp), %edx
    0x2aa4 <+99>:  movl   %edx, 0x8(%esp)
    0x2aa8 <+103>: movl   0x4000, %edx
    0x2aae <+109>: movl   %edx, 0x4(%esp)
    0x2ab2 <+113>: movl   %eax, (%esp)
    0x2ab5 <+116>: calll  0x2cd2                    ; symbol stub for: objc_msgSend
    0x2aba <+121>: testb  %al, %al
    0x2abc <+123>: setne  %al
    0x2abf <+126>: leave
    0x2ac0 <+127>: retl
```
Okay that’s a lot of gibberish there, I remember something about ebp and esp from school… Something about stack and base pointers. To defeat this Unicorn I should refresh my memory (get it…? “memory") and understand what’s going on here. [Back to school!](https://www.youtube.com/playlist?list=PLPXsMt57rLthf58PFYE9gOAsuyvs7T5W9)

Now that the assembly above doesn’t look scary anymore, and knowing Objective-C is a runtime language, I should be able to reverse engineer the whole method just by using the debugger and breaking on the msgSend. I found this excellent [paper](https://reverse.put.as/wp-content/uploads/2011/06/objective-c-internals.pdf) by André Pang explaining this in dept. At this point I feel comfortable I got him. Let’s try to work our magic in the debugger.
```bash
(lldb) b *0x00002a41
Breakpoint 1: where = Unicorn`-[UnicornAppDelegate validateSerial:forName:], address = 0x00002a41
(lldb) c
Process 894 resuming
```
I type my name and some random serial in the box and press the button.
```bash
Unicorn`-[UnicornAppDelegate validateSerial:forName:]:
->  0x2a41 <+0>: pushl  %ebp
    0x2a42 <+1>: movl   %esp, %ebp
    0x2a44 <+3>: subl   $0x18, %esp
    0x2a47 <+6>: movl   $0x3044, 0x8(%esp)
```
The breakpoint is hit, let the fun begin.
Somethings stand out in the assembly, for instance 0x3044. Let’s see if we can figure out what this is

```bash
(lldb) x/a 0x3044
0x00003044: 0xa37b7600 CoreFoundation`__NSCFConstantString
```
We should be able to PO this
```bash
(lldb) po 0x3044
+unicorn
```
Hmmm so we have a constant string “+unicorn”, my first guess is that this is some kind of salt added to the name. Let’s confirm this is what’s really going on. The thing most interesting to me is what happens in the objc_msgSend methods. We’ve learned how a Objective-C method is invoked and what this does in memory, so if we step into these methods we should be able to exactly figure out what’s going on. We step next until we get to the message send method, there we step in.
```bash
(lldb) s
Process 894 stopped
* thread #1: tid = 0x25233, 0x00002cd2 Unicorn`objc_msgSend, queue = 'com.apple.main-thread', stop reason = instruction step into
    frame #0: 0x00002cd2 Unicorn`objc_msgSend
```
We know that before the call is executed the receiver is in $esp and after executing the receiver is in $esp+4. The command follows after in $esp+8, arguments start at $esp+12. Let’s put this to the test:
```bash
(lldb) po *(id *)($esp + 4)
Cedrick
(lldb) po *(SEL *)($esp + 8)
"stringByAppendingString:"
(lldb) po *(id *)($esp + 12)
+unicorn
```
We confirmed our suspicion and now know that a new string is generated by concatenating the name with our +unicorn constant. From here on we use the same technique reverse the rest of the algorithm.




