import os, sys, subprocess, datetime

dt_threshold = datetime.datetime(2023, 6, 16).timestamp()

_, indir, outdir = sys.argv
for x in os.listdir(indir):
    inpath = os.path.join(indir, x)
    if os.stat(inpath).st_mtime > dt_threshold:
        if subprocess.run(("feh", inpath)).returncode == 0:
            newname = input(x + ": ")
            if newname:
                ctr = 1
                while True:
                    newpath = os.path.join(outdir, newname + (f"-{ctr}" if ctr > 1 else "") + os.path.splitext(x)[1])
                    if os.path.exists(newpath):
                        print("already in use")
                        ctr += 1
                    else:
                        os.rename(inpath, newpath)
                        break
            else:
                print("keeping")
