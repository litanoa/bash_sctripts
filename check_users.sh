#!/bin/bash

# Extract data from userlist.json
users_data=$(jq -c '.users[]' userlist.json)

for user in $users_data; do
    # Extract user details
    username=$(echo $user | jq -r '.username')
    primary_group=$(echo $user | jq -r '.primary_group')
    secondary_groups=$(echo $user | jq -r '.secondary_groups | join(",")')
    
    echo "Processing user $username..."

  # Create primary group if it doesn't exist
    grep -q -w "$primary_group" /etc/group
    if [ $? -ne 0 ]; then
        sudo groupadd "$primary_group"
        echo "Created primary group $primary_group."
    fi

# Create or modify user
    grep -q -w "^$username:" /etc/passwd
    if [ $? -ne 0 ]; then
        # Create user's home directory
        mkdir -p "/home/$username"
        
        sudo useradd -m -g "$primary_group" -d "/home/$username" "$username"
        echo "Created user $username with primary group $primary_group and home directory at /home/$username."

   # Set ownership and permissions for the home directory
        sudo chown "$username:$primary_group" "/home/$username"
        sudo chmod 744 "/home/$username"
        echo "Set proper ownership and permissions for /home/$username."
    else
        echo "User $username already exists."
    fi

    # Secondary groups
    for group in ${secondary_groups//,/ }; do
        grep -q -w "$group" /etc/group
        if [ $? -ne 0 ]; then
            sudo groupadd "$group"
            echo "Created secondary group $group."
        fi
    done

    # Update user secondary groups
    sudo usermod -G "$secondary_groups" "$username"
    echo "Updated groups for user $username to: $secondary_groups."
done

# Проверка пользоватлей в диапазоне между 1000 и 60000
users_to_check=$(awk -F: '$3 >= 1000 && $3 <= 60000 {print $1}' /etc/passwd)

users_from_json=$(jq -r '.users[].username' userlist.json)
users_to_delete=""

for user in $users_to_check; do
    echo "$users_from_json" | grep -q -w "$user"
    if [ $? -ne 0 ]; then
        users_to_delete="$users_to_delete $user"
    fi
done

for user in $users_to_delete; do
    sudo userdel -r "$user"
    echo "Deleted user $user."
done

# Display results based on userlist.json
echo ""
echo "____Users and groups____"
echo ""
for user in $users_from_json; do
    echo "User: $user"
    echo "Groups: $(id -Gn "$user")"
    echo ""
done
echo "________________________"
