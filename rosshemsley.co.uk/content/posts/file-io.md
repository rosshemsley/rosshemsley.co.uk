---
title: "Thoughts on code review: File IO"
date: 2019-01-12T13:07:20Z
categories: [engineering, code-review]
tags: [go,code review, engineering]
---

When it comes to reviewing code that does any kind of file IO, there are a number of patterns that I find myself discouraging quite often. Interestingly, I have found that these patterns are rarely considered in discussions around code review and clean code.

In this post, I will explore some of these patterns in more depth, and discuss why I believe it's worth taking the time to do things slightly differently in many cases.

Let's start with a toy example in Go. The advice here applies equally well to Python and C++ and we'll cycle back to those languages later. In our example, we'll open up a json file and print some information about it. This will serve as a sufficient
example to illustrate some anti-patterns around file IO that can be elegantly avoided.

Consider code-reviewing the following snippet, and take a mental note of any comments you might have around the file IO.
Let's see if we end up agreeing :)

{{< highlight go "linenos=table" >}}
func main() {
    // YOLO flag passing, you should use kingpin
    // or similar in real code
	jsonFile := os.Args[1]

	err := readSomeJSON(jsonFile)
	if err != nil {
		log.Fatalf("Failed: %s", err)
	}
}

// readSomeJSON reads a json file and
// prints how many keys it has.
func readSomeJSON(jsonFile string) error {
	data, err := parseJSON(jsonFile)
	if err != nil {
		return err
	}

	fmt.Printf("file contains %d keys\n", len(data))
	return nil
}

// parseJSON loads json from a file into a map.
func parseJSON(jsonFile string) (map[string]interface{}, error) {
	bs, err := ioutil.ReadFile(jsonFile)
	if err != nil {
		return nil, err
	}

	var result map[string]interface{}

	err = json.Unmarshal(bs, &result)
	if err != nil {
		return nil, err
	}

	return result, err
}
{{< / highlight >}}

## Variable naming

First thing's first, let's talk about variable naming. A review comment I often leave is,

> _Avoid calling variables that hold paths_ '`file`'_. Always use_ `path` _instead._

In the example above, we should name our variable `jsonPath` (or similar). The reasoning here is that almost every language has a built-in type called `file`, which usually references an actual file descriptor. Save your `file` variable name for this!

{{< highlight go "linenos=table" >}}
path := "/tmp/foo"
file, err := os.Open(path)
{{< / highlight >}}

The advice applies equally well to variables called `dir` that actually contain _paths_  to directories. This may seem overly nit-picky, but being precise is always valuable to aid reading code. Additionally, there are other good reasons to be picky here, hopefully I'll convince you of these in the next points.

## Passing around system paths

The next thing I would like to talk about is **passing around paths**.
My approximately true rule is,

> _Never pass around system paths in your code. Always pass around file-like-objects._

This is a comment I often leave when I see a chain of functions passing a system path down several levels, or a long-lived object that stores a reference to a system path - patterns that pop up surprisingly frequently. There are several reasons why I believe these are antipatterns, but let's start by defining exactly what I mean by _file-like objects_.

In Go, I consider `io.Reader` and friends file-like-objects. In Python, an equivalent would be `typing.BinaryIO`.
In C++, you can use `std::iostream`... yes, I know that `iostream` is deeply unfashionable, I will also accept any viable alternative.

Sometimes people interpret this advice incorrectly and use the type `os.File` or `std::fstream`, or another _concrete_ file type, however to fully benefit from this advice, I encourage you to

> _always use the most general purpose file-like-object type available_

Now we've got that out of the way, let's dive into the _why_.

#### The path may be invalid
The path you are passing around may refer to a resource that is not accessible by your program (e.g. incorrect path or permissions). This means the error-handling code that deals with bad user input must live at the _bottom_ of the call stack next to where the path is opened, which will end up being far away from where the path was actually defined. This makes it harder for the programmer to make decisions based on this event. I believe the following factoring is always cleaner,

{{< highlight go "linenos=table" >}}
path := os.Args[1]

// Deal with the path being invalid as close to
// the place where the path is defined as possible.
f, err := os.Open(path)
if err != nil {
    log.Fatalf("Looks like I can't read the file: %v", err)
}

// This function doesn't have to deal
// with invalid paths any more.
useFile(f)
{{< / highlight >}}

Long-lived objects that store file paths can be particularly troublesome, because you may only find out that your object was incorrectly initialised with a non-existent path much later, with no obvious way to gracefully handle the error.

#### Testing
Suppose I want to test my original example code, particularly the funcion `readSomeJSON()`. My only practical option is to craft a fixture and check my code gives the correct answer. This is a reasonable thing to do, but no one wants to create multiple fixtures per function call, and so usually the test ends up being a simple _happy-path_ test rather than a test that exercises tricky cases or important classes of bugs. If our function took an `io.Reader` instead, we could write a _table driven test_ to test many possible inputs concisely and efficiently by creating a reader from an in-memory string.

{{< highlight go "linenos=table" >}}
func TestReadSomeJSON(t *testing.T) {
    var tests = []struct {
        in  string
        hasErr bool
    }{
        {`{"foo": 1}`, false},
        {`{"foo": 1, "bar": 2}`, false},
        {`{foo": 1; "bar": 2}`, true},
        {``, true},
    }

	for _, tt := range tests {
		t.Run(tt.in, func(t *testing.T) {
			err := readSomeJSON(bytes.NewReader([]byte(tt.in)))
            if (err != nil) != tt.hasErr {
				t.Errorf("error didn't match expected value")
			}
		})
	}
}
{{< / highlight >}}

This is particularly valuable when we are parsing some tricky format into an in-memory structure. Following this pattern has saved me a lot of time over the years by making it easier to catch bugs early.

#### Flexibility

When I come across libraries with APIs that take paths, and provide no obvious alternative using a file-like object, I am particularly disappointed. In many cases I have just received some data from the network, and I want to decode it with a library. If the library only accepts files, I am forced to spill a temporary file to disk or use a horrible hack such as [fmemopen](http://pubs.opengroup.org/onlinepubs/9699919799/functions/fmemopen.html). My experience has been that this kind of pattern leads to fragile code that breaks in production and wakes me up at inappropriate times of the night. Often the culprit is C code, because C has no good alternative to `io.Reader`. I recently wrote a Go shim around the C-library '`ffmpeg`' which made it possible to read a video from an in-memory Go buffer. Getting it to work took several days because essentially all of the built-in functions in ffmpeg take `char*` system paths, and I had to resort to writing a custom IO context to accompllish a task as simple as reading video from an in-memory buffer!

> Always make your APIs take file-like-objects (or at least provide an alterative to providing system paths). Helpers that open paths are fine, but probably they should only be provided to write concise examples.

#### Future refactors and chaining

Here's an example of a library I wrote that reads MNIST data, providing two APIs for reading data from path or from a reader, [MNIST reader](https://github.com/rosshemsley/gonn/blob/master/mnist/mnist.go#L16) (TODO: fix leak...).

The example link above illustrates another useful property of passing around file-like-objects - they can be **chained** with other operators, such as a decompressor. A pattern I have executed multiple times now is to move from storing raw json files on disk to storing gzipped json files. If I have factored my code to take `io.Reader` objects everywhere rather than paths, then I can easily add a shim between the file and the function to transparantely decompresses the input. Even more powerful, is that I can make my reader automatically _detect_ gzipped data and add a decompressor to the reader only when required. This change doesn't have to touch any of the tests or business logic in the parsing code.

#### Race conditions

Race conditions can occur when the user changes something about the file system that your program is reading from, for example deleing or moving files whilst your program is running.

It's important to remember that a path offers no guarantees about the file it points to. The path may exist when the program starts, but later when the path is used, it may have been deleted, or moved, or corrupted. File-like-objects on the other hand provide far stronger guarantees.

> Always remember, your operating system provides you with strong guarantees about file-descriptors.

A useful thing to know is that Posix operating systems will only remove a file when all references to it have expired, meaning that once you have opened your path to obtain your file-like-object, it will remain valid for reading and writing _even if the user deletes it_. This can be a neat trick where you open a temporary file and then delete it - you can still use the file as normal because the OS won't remove it until you close the file, but in the event that your program terminates unexpectedly, the file will be cleaned up by the operating system. In general, if you have a long-lived object that references a file, always prefer to store an object that holds a file descriptor rather than a system path. This way, you can remove a whole class of potential bugs due to users altering the file system during runtime.

#### Resource leaks

It's also easy to accidentally leak file descriptors when you forget to close a file. Keeping all of the logic around opening paths at the very top level of your code makes it far easier to audit code for correctness, and help track down resource leak errors quickly without traversing the entire codebase for instances of files being opened.

#### Simplifying handling of cross-platform code

We must not forget that not all operating systems have the same semantics around file systems and directory structures. My personal preference is to hoist all logic that deals with my specific OS as high as possible, away from my pure business logic.  For example, I would recommend trying to avoid using operations such as "list directory" or path joining/expansion in functions that also do business logic. Keep all of these things as high as possible, next to the places where the paths are fed into your program. Try to keep all business logic free of operating-system specific operations.

## Stream reading

One way to deal with reading files is to read the whole thing into memory and then pass down the bytes to later levels. I would generally discourage this pattern. In many cases it is possible to _incrementally_ parse data (in particular, if your data is stored as csv, json lines, or delimited protobuf). In this case, feeding your function an `io.Reader` is the perfect way to pass a dependency without loading it all into memory. Sometimes factoring in this way can shave tens of seconds from the init time of your executables when they load very large files at startup.

## When should I ignore this advice?

As with every rule, there are exceptions. In particular, we cannot ignore the fact that file descriptors are system resources, and so any program that has to handle thousands of files may cause the OS to run out of file descriptors if all of them are held open at all times. In those cases, we sometimes have to break the rules. My argument in this post is that the most common workload is reading files containing data or config, and that usually we should switch out raw paths for file-like objects as early as possible.
As with every rule, there are exceptions. In this case, we cannot ignore the fact that file descriptors are system resources, and so any program that has to handle thousands of files may experience other issues if all of them are held open at all times. In those cases, we sometimes have to break the rules. My argument in this post is that the most common workload is reading files containing data or config, and that usually we should switch out raw paths for file-like objects as early as possible.

Another exampe where writing APIs that take paths may necessary is when using memory-mapping. In this case, you can consider offering alternative APIs that take raw buffers of bytes for users that do not wish to spill to disk.

## Corrected example

In summary, I hope I've convinced you to think carefully about file IO in future. If anyone has any other perpectives on the subject, I would be interested to hear from you! For completeness, here's the original snippet with some of the above advice applied. The changes are small, but I believe the wins are significant.


{{< highlight go "linenos=table" >}}
func main() {
    // YOLO flag passing, you should use kingpin
    // or similar in real code
	jsonPath := os.Args[1]

    f, err := os.Open(jsonPath)
    if err != nil {
        log.Fatalf("Failed to open json file: %v", err)
    }
    defer f.Close()

	err := readSomeJSON(f)
	if err != nil {
		log.Fatalf("Failed: %s", err)
	}
}

// readSomeJSON reads a json reader and
// prints how many keys it has.
func readSomeJSON(jsonReader io.Reader) error {
	data, err := parseJSON(jsonReader)
	if err != nil {
		return err
	}

	fmt.Printf("json contains %d keys\n", len(data))
	return nil
}

// parseJSON loads json from a file into a map.
func parseJSON(jsonReader io.Reader) (map[string]interface{}, error) {
    // Note, we could have passed the reader to a
    // json.Decoder, but a little-known fact is that
    // json.Decoder accepts more general inputs than json.Unmarshal,
    // and so that would change the semantics of this code.
	bs, err := ioutil.ReadAll(jsonReader)
	if err != nil {
		return nil, err
	}

	var result map[string]interface{}

	err = json.Unmarshal(bs, &result)
	if err != nil {
		return nil, err
	}

	return result, err
}
{{< / highlight >}}