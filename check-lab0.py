#!/usr/bin/env python3
import os
import sys
import subprocess
import shutil

subprocess.run(args=['git', 'clone', sys.argv[1]],
               capture_output=True,
               text=True)

if (not os.path.isdir("./lab0-c")):
    print("git clone Fail")
    exit(1)
os.chdir("./lab0-c")
comp_proc = subprocess.run(args=['git', 'log', '--pretty=format:%h message: %s body: %b END'],
                           capture_output=True,
                           text=True)
git_commit = comp_proc.stdout
commits = []
flag = False
for commit in git_commit.split("END\n"):
    tmp = []
    tmp.append(commit[0:commit.find("message:") - 1].strip())
    tmp.append(commit[commit.find("message:") +
               8:commit.find("body:")].strip())
    tmp.append(commit[commit.find("body:") + 5:].strip())
    if (tmp[0] == "267cca7"):
        flag = True
        break
    commits.append(tmp)
if (not flag):
    print("The repository does not include the commit 267cca7a86d6dc3e4a315364742a630663e7f7d3")

for commit in commits:
    if commit[2] != "":
        commit[1] = commit[1] + "\n\n" + commit[2]
    comp_proc = subprocess.run(args=['../check-git-commit.sh', commit[1]],
                               capture_output=True,
                               text=True)
    if (comp_proc.stdout != ""):
        print("git commit messege does not meet the format")
        print(comp_proc.stdout)


output = subprocess.run(args=['make', 'test'],
                        capture_output=True,
                        text=True).stdout
                        
print(output[output.find("TOTAL\t\t")+7:-9])
if (int(output[output.find("TOTAL\t\t")+7:-9]) >= 95):
    print("PASS")
else:
    print("FAIL: socre {} is less then 95".format(output[output.find("TOTAL\t\t")+7:-9]))

os.chdir("../")
shutil.rmtree("./lab0-c")