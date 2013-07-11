If you're on this page, you must be interested in spending some time giving back to this humble project. If that's the case, here are some ways you can help build the future of the Video.js SWF:

- Features and changes
- Bug reports and fixes
- Answer questions on Stack Overflow
- Related Video.js projects

##Getting Started

1. Fork the video-js-swf git repository. At the top of every github page, there is a Fork button. Click it, and the forking process will copy video-js-swf into your organization. You can find more information on Forking a Github repository here.

2. Clone your fork of the video-js-swf repo, and assign the original repo to a remote called "upstream"
```bash
git clone https://github.com/<your-username>/video-js-swf.git
cd video-js-swf
git remote add upstream https://github.com/videojs/video-js-swf.git
```
In the future, if you want to pull in updates to video-js-swf that happened after you cloned the main repo, you can run:
```bash
git checkout master
git pull upstream master
```

3. Depending on whether you're adding something new, making a change or fixing a bug, you'll want to do some up-front preparation.

  If you're adding new functionality, you only need to create a new branch for your work. When you submit a Pull Request, Github automatically opens a new issue to track it.

  If you're fixing a bug, please submit an issue for it. If you're fixing an existing bug, claim it by adding a comment to it. This will give a heads-up to anyone watching the issue that you're working on a fix. Please refer to the [Filing Bugs](#bugs) section below for some guidelines on filing new issues.
        
4. Create a new branch for your work.

4. Since you've installed and built video.js already, you may already be familiar with the [Zencoder Contribflow](https://github.com/zencoder/contribflow) node moule.  You can use Contribflow to simplify your workflow with video-js-swf too!
If you haven't done it already, you can install Contribflow easily.
  
  On Unix-based systems, you'll have to do this as a superuser:
  `sudo npm install -g contribflow`

  On Windows, you can just run:
  `npm install -g contribflow`

5. Create a new branch for your work.

  Since the issue filing process is described elsewhere, let's assume that you've filed or claimed the issue already.
  Next, create the branch. You'll use contrib to do this task.

  Run this command for new features:
  ```bash
  contrib feature start
  ```

  Run this command if you're fixing an issue:
  ```bash
  contrib hotfix start
  ```

  You will be prompted to name the branch.  After that, contrib will create the branch locally, and use git to push it up to your origin, and track it.  You're now ready to start building your feature or fixing that bug!

6. Thoroughly test your feature or fix. In addition to new unit tests, and testing the area(s) specific to the area you're working on, a brief smoketest of the player never hurts. We'd like to suggest this short smoke test with both FLV and MP4 video formats:
  1. Playback should start after clicking Play overlay
  2. Playback should start after clicking Play button
  3. Playback should pause when clicking the Pause button
  4. Seeking should work by clicking in the timeline
  5. Seeking should work by dragging the scrubber in the timeline
  6. Full screen (and restore from Full-screen) should work
  7. Replay (without refreshing the browser) should work

  (This may seem like a lot of steps, but they could all be accomplished with a couple of short-duration test files, within a few minutes.)

7. Use contrib to submit your [Pull Request](#pull-requests).

  First, checkout your feature or issue branch:
  ```bash
  git checkout (branchname)
  ```

  Next, submit your Pull Request, for your new feature:
  ```bash
  contrib feature submit
  ```
  Or for your bug fix:
  ```bash
  contrib hotfix submit
  ```

  You'll be prompted for title and description for the Pull Request.  After that, contrib will use Git to submit your Pull Request to video-js-swf.

##Filing Bugs

A bug is a demonstrable problem that is caused by the code in the repository. Good bug reports are extremely helpful. Thank You!

Guidelines for bug reports:

- Use the GitHub issue search — check if the issue has already been reported.
- Check if the issue has been fixed — try to reproduce it using the latest master branch in the repository.
- Isolate the problem — ideally create a reduced test case and a live example.

A good bug report should be as detailed as possible, so that others won't have to follow up for the essential details.

Here's an example:

    Summary: Short yet concise Bug Summary

    Description: Happens on Windows 7 and OSX. Seen with IE9, Firefox 19 OSX, Chrome 21, Flash 11.6 and 11.2

        This is the first step
        This is the second step
        Further steps, etc.

    Expected: (describe the expected outcome of the steps above)

    Actual: (describe what actually happens)

    <url> (a link to the reduced test case, if it exists)

    Any other information you want to share that is relevant to the issue being reported. This might include the lines of code that you have identified as causing the bug, and potential solutions (and your opinions on their merits).

####NOTE: Testing Flash Locally in Chrome

Chrome 21+ (as of 2013/01/01) doens't run Flash files that are local and loaded into a locally accessed page (file:///). To get around this you can do either of the following:

1. Do your development and testing using a local HTTP server.
2. Disable the version of Flash included with Chrome and enable a system-wide version of Flash instead.

Other Video.js Projects
Video.js - Our open source HTML5 & Flash video player.
Videojs.com - The public site with helpful tools and information about Video.js.

