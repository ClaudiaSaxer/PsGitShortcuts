# Comment help: http://blogs.technet.com/b/heyscriptingguy/archive/2010/01/07/hey-scripting-guy-january-7-2010.aspx

###################################################################################################################
### Add, Commit, Push related functions
###################################################################################################################

<#
    .SYNOPSIS 
        Push everything to the remote repository.
    .Description
        1) Add ALL files.
        2) Commits the changes.
        3) Pushes the commit to the configured remote repository.
    .PARAMETER msg
        The commit message.
    .EXAMPLE
        Up "My Message"
        Pushes all changes to the server using the given commit message.
#>
Function Up() {
    param([Parameter(Mandatory=$True)][string]$msg )
        
    CommitAll $msg
    git push
}

<#
    .SYNOPSIS 
        Commits everything to the local repository.
    .Description
        1) Add ALL files.
        2) Commits the changes.
    .PARAMETER msg
        The commit message.
    .EXAMPLE
        CommitAll "My Message"
        Commits all changes using the given commit message.
#>
Function CommitAll() {
    param(
        [Parameter(Mandatory=$true)][string]$msg )
        
    git add -A
    git commit -m $msg
}

###################################################################################################################
### Log related functions
###################################################################################################################

<#
    .SYNOPSIS 
        Prints the number of commits by each author.
    .Description
        Uses git shortlog feature to print out the number of commits per author.
        Command used: 
            If $allBranches set to false:
                git shortlog -s -n
            If $allBranches set to true:
                git shortlog -s -n --all
    .PARAMETER allBranches
        A value determining whether the commits of all branches ($True) or only of the current branch ($False) should be counted.
    .EXAMPLE
        CommitCount
        Print commit count of current branch only.
    .EXAMPLE
        CommitCount $true
        CommitCount -allBranches $true
        Print commit count of all branches.
#>
Function CommitCount() {
    param([bool]$allBranches = $false)
    
    if($allBranches) {
        git shortlog -s -n --all
    }
    else {
        git shortlog -s -n
    }
}

<#
    .SYNOPSIS 
        Gets the name of each author.
    .Description
        Gets the name of each author.
    .EXAMPLE
        GetAuthors
        Gets the authors.
#>
Function GetAuthors() {
    return git log --format='%aN' | sort -u
}

<#
    .SYNOPSIS 
        Gets the number of changes per author.
    .Description
        Gets the number of changes per author.
    .PARAMETER author
        The name of the author to get the stats of.
    .PARAMETER allBranches
        A value determining whether the commits of all branches ($True) or only of the current branch ($False) should be counted.
    .EXAMPLE
        GetChangesByAuthor
        Gets the number of changes of all authors (current branch).
    .EXAMPLE
        GetChangesByAuthor "athor name" $True
        Gets the number of changes of the user with the given name (all branches).
#>
function GetChangesByAuthor() {
    param(
        [Parameter(Mandatory=$False)][string]$author,
        [Parameter(Mandatory=$False)][bool]$allBranches = $false
    )
    
    if(!$author){
        $authors = GetAuthors
    } else {
        $authors = [array] $author;
    }
    $result = @()
    
    ForEach($authorName in $authors) {
        If($allBranches) {
            $log = git log --author="$authorName" --pretty=tformat: --numstat --all
        }
        Else {
            $log = git log --author="$authorName" --pretty=tformat: --numstat
        }

        $lines = $log.Split("`r`n")
        
        $add = 0
        $delete = 0
        
        ForEach($line in $lines) {
            $values = $line.Split()
            Try {
                $add +=  [convert]::ToInt32($values[0], 10)
                $delete +=  [convert]::ToInt32($values[1], 10)
            }
            Catch {	}			
        }
        
        $result += (New-Object PSObject -Property  @{ 'Add' = $add; 'Delete' = $delete; 'All' = $add + $delete; 'Author' = $authorName; })
    }
    
    return $result | Sort-Object All -Descending
}

<#
    .SYNOPSIS 
        Prints a visual tree of the repository history.
    .Description
        Prints a visual tree of the repository history.
    .EXAMPLE
        GitTree
        Prints a commit tree.
#>
Function GitTree() {
	git log --graph --abbrev-commit --decorate --format=format:'%C(bold Magenta)%h%C(reset) - %s%C(reset) - %C(bold cyan)%an%C(reset) %C(bold green)(%ar)%C(reset) %C(dim white) %C(bold yellow)%d%C(reset)'
	
	# Alternatives
	# git log --oneline --decorate --all --graph
	# git log --graph --full-history --all --color --pretty=format:"%x1b[31m%h%x09%x1b[32m%d%x1b[0m%x20%s"
	# lgit og --graph --abbrev-commit --decorate --format=format:'%C(bold Magenta)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)'
	# git log --graph --abbrev-commit --decorate --format=format:'%C(bold Magenta)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(bold yellow)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)'
	# git log --graph --abbrev-commit --decorate --format=format:'%C(bold Magenta)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset) %C(bold cyan)(committed: %cD)%C(reset) %C(bold yellow)%d%C(reset)%n''          %C(white)%s%C(reset)%n''          %C(dim white)- %an <%ae> %C(reset) %C(dim white)(committer: %cn <%ce>)%C(reset)'
}

###################################################################################################################
### Merge, sync. related functions
###################################################################################################################

<#
    .SYNOPSIS 
        Synchronizes the current branch with another branch.
    .Description
        Synchronizes the current branch with another branch.
        If a commit message is provided, this command will also commit
        all local changes.
        
        1)  Commit everything if $msg is specified.
        2)  Check for remote changes.
        3)  Pull changes.
        4)  Checkout other branch.
        5)  Check for remote changes.
        6)  Pull changes.
        7)  Merge with current branch.
        8)  Push.
        9)  Checkout current branch.
        10) Merge with target branch.
        11) Push.
    .PARAMETER msg
        The commit message.
    .PARAMETER targetBranch
        The target branch.
    .EXAMPLE
        SyncBranches master
        SyncBranches -targetBranch master
        Synchronizes the current branch with master.
    .EXAMPLE
        SyncBranches master "My Message"
        SyncBranches -targetBranch master -msg "My Message"
        Commits all changes and synchronizes the current branch with master.
#>
Function SyncBranches() {
    param(
        [Parameter(Mandatory=$true)][string]$targetBranch,
        [Parameter(Mandatory=$False)][string]$msg)
    
    $currentBranch = git name-rev --name-only HEAD
    if($msg) {
        CommitAll $msg
    }
    
    $contunue = TryMergeRemoteBranch
    if($contunue -eq $False) {
        return;
    }
    
    git checkout $targetBranch
    $contunue = TryMergeRemoteBranch
    if($contunue -eq $False) {
        return;
    }
    
    git merge $currentBranch --no-ff
    git push
    git checkout $currentBranch
    git merge $targetBranch --no-ff
    git push
}

<#
    .SYNOPSIS 
        Tries to merge the local branch with the matching remote branch.
        Returns $True if the merge was successfully; otherwise, $False.
    .Description
        Tries to merge the local branch with the matching remote branch.
        Returns $True if the merge was successfully; otherwise, $False.
    .EXAMPLE
        TryMergeRemoteBranch
        Tries to merge the branch.
#>
Function TryMergeRemoteBranch() {
    git remote update
    $result = git status -uno
    if($result -And $result.Length -gt 1) {
        if($result[1].Contains("Your branch is up-to-date")) {
            return $True
        }
    }
    
    Write-Host "Pending merge detected" -ForegroundColor Yellow -BackgroundColor Black
    git pull
    
    $conflicts = git ls-files -u
    if($conflicts.Length -ne 0) {
        Write-Host "Conflicts detected!" -ForegroundColor Red -BackgroundColor Black
        return $False
    }
    
    return $True
}

<#
    .SYNOPSIS 
       Deletes the specified file completely from the repository inc. history.
    .Description
        Runs two times:
        1) filter-branch to find the file and delete it.
        2) reflog and gc to cleanup the repository.
        https://help.github.com/articles/remove-sensitive-data/
    .PARAMETER file
        The file to delete.
    .EXAMPLE
        DeleteFileCompletely movie.avi
        Deletes movie.avi for the repository inc. history.
#>
Function DeleteFileCompletely() {
     param(
        [Parameter(Mandatory=$true)][string]$file )

    # Needs to run twice to work.... I don't know why but it works only the second time?!
    For ( $i = 0; $i -le 1; $i++ ) {
        # Delete the file.
        git filter-branch --force --index-filter "git rm --ignore-unmatch --force -r $file" --prune-empty --tag-name-filter cat -- --all

        # Cleanup the repository.
        git reflog expire --all --expire=now
        git gc --prune=now --aggressive
    }
}

<#
    .SYNOPSIS 
        Removes the specified file from the index and adds it to the .gitignore file.
    .Description
        1) Removes the file from the index.
        2) Adds the file to the .gitignore file.
    .PARAMETER file
        The file to remove.
    .PARAMETER ignoreFile
        The path to the .gitignore file, if not specified the .gitignore file at the current location will be used.
    .EXAMPLE
        IgnoreFile test.txt
        Removes test.txt from the index and adds it to the .gitignore file.
    .EXAMPLE
        IgnoreFile test.txt subfolder\.gitignore
        Removes test.txt from the index and adds it to the specified .gitignore file.
#>
Function IgnoreFile() {
     param(
        [Parameter(Mandatory=$true)][string]$file,
        [Parameter(Mandatory=$false)][string]$ignoreFile)

    if( !$ignoreFile ) {
    $ignore = Get-ChildItem -Filter .gitignore
        if( !$ignoreFile.Count ) {
            Write-Host "Could not find a .gitignore file, please run this command where your .gitignore file is located, or provide the $ignoreFile parameter." -ForegroundColor Red -BackgroundColor Black
            return
        }
        $ignoreFile = $ignore.FullName
    }

    git rm --cached $file
    Add-Content $ignoreFile "`n$file"
}

Function GetRepositoryRoot() {
	
}

 <#
    .SYNOPSIS 
       Configures the git user data.
    .Description
        Sets the user name and the user email globally or local.
		Runs:
			git config --global user.name "John Doe"
			git config --global user.email "john@example.com"
    .PARAMETER name
        The user name.
    .PARAMETER email
        The user email address.
    .PARAMETER global
        A value determining whether the configuration gets applied globally or not.
    .EXAMPLE
		SetUserData "User Name"
		Sets the user name globally.
		
		SetUserData "User Name" "mail@gmail.com"
		Sets the user name and email globally.
		
		SetUserData "User Name" "mail@gmail.com" $false
		Sets the user name and email localy.
#>
Function SetUserData() {
	param(
        [Parameter(Mandatory=$False)][string] $name = $null,
        [Parameter(Mandatory=$False)][string] $email = $null,
		[Parameter(Mandatory=$False)][bool] $global = $true)
	
	# user name
	if($name) {
		if($global) {
			git config --global user.name $name
		}
		else {
			git config user.name $name --replace-all
		}
	}
	# user password
	if($email) {
		if($global) {
			git config --global user.email $email
		}
		else {
			git config user.email $email --replace-all
		}
	}
 }

<#
    .SYNOPSIS 
        Prints the PS git shortcuts help.
    .Description
        Prints a basic help text.
    .EXAMPLE
        PsGitHelp
        Prints the help text.
#>
Function PsGitHelp() { 
    $functions = @(
        @{ Name = "Up"; Text = "Add, Commit, Push."; }
		@{ Name = "CommitAll"; Text = "Add -A, Commit."; }
        @{ Name = "CommitCount"; Text = "Print number of commits."; }
        @{ Name = "SyncBranches"; Text = "Sync the current branch with another branch."; }
        @{ Name = "DeleteFileCompletely"; Text  = "Deletes the specified file completely from the repository inc. history." }
        @{ Name = "IgnoreFile"; Text  = "Removes the specified file from the index and adds it to the .gitignore file." }
        @{ Name = "GetAuthors"; Text  = "Gets the name of each author." }
    )
    
    $maxLength = 0;
    ForEach($x in $functions) {
        if($x.Name.Length -gt $maxLength) {
            $maxLength = $x.Name.Length
        }
    }
    
    $maxLength += 2
    ForEach($x in $functions) {
        Write-Host $x.Name.PadRight($maxLength, ' ') "("$x.Text ")";
    }
    Write-Host "Use 'Get-Help [FunctionName]' to get more detailed help for a function."
}

# Export functions
Export-ModuleMember -Function Up, CommitAll, CommitCount, GetAuthors, GetChangesByAuthor, GitTree, SyncBranches, DeleteFileCompletely, IgnoreFile, SetUserData,  PsGitHelp