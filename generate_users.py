import os
import subprocess
import xml.etree.ElementTree as ET
import csv

cc_filepath="volume-configs/callcenter.conf.xml"
input_users_dirpath="input-users"
output_users_dirpath="output-users"

conf_template = """
<configuration name="callcenter.conf" description="CallCenter">
  <settings>
    <param name="truncate-agents-on-load" value="true"/>
    <param name="truncate-tiers-on-load" value="true"/>
  </settings>

  <queues>
  {queues}
  </queues>

  <agents>
  </agents>
  <tiers>
  </tiers>

</configuration>
""".strip()

queue_template = """
<queue name="{extension}@default">
    <param name="strategy" value="ring-all"/>
    <param name="moh-sound" value="$${{hold_music}}"/>
    <param name="time-base-score" value="system"/>
    <param name="max-wait-time" value="120"/>
    <param name="max-wait-time-with-no-agent" value="0"/>
    <param name="max-wait-time-with-no-agent-time-reached" value="0"/>
    <param name="tier-rules-apply" value="false"/>
    <param name="tier-rule-wait-second" value="300"/>
    <param name="tier-rule-wait-multiply-level" value="false"/>
    <param name="tier-rule-no-agent-no-wait" value="false"/>
    <param name="discard-abandoned-after" value="60"/>
    <param name="abandoned-resume-allowed" value="false"/>
</queue>
"""

users_teplate = """
<include>
{users}
</include>
""".strip()

intercom_template = """
<user id="{extension}">
    <params>
        <param name="password" value="{password}"/>
    </params>
    <variables>
        <variable name="toll_allow" value="domestic,international,local"/>
        <variable name="accountcode" value="{extension}"/>
        <variable name="user_context" value="intercoms-main"/>
        <variable name="effective_caller_id_name" value="{extension}"/>
        <variable name="effective_caller_id_number" value="{extension}"/>
        <variable name="outbound_caller_id_name" value="$${{outbound_caller_name}}"/>
        <variable name="outbound_caller_id_number" value="$${{outbound_caller_id}}"/>
        <variable name="sip-force-contact" value="NDLB-connectile-dysfunction"/>
        <variable name="X-Doma-AI-Type" value="intercom"/>
    </variables>
</user>
"""

apartment_template = """
<user id="{extension}">
    <params>
        <param name="password" value="{password}"/>
        <param name="vm-password" value="{extension}"/>
    </params>
    <variables>
        <variable name="toll_allow" value="domestic,international,local"/>
        <variable name="accountcode" value="{extension}"/>
        <variable name="user_context" value="rooms-main"/>
        <variable name="effective_caller_id_name" value="room house 1 apart 1"/>
        <variable name="effective_caller_id_number" value="room-1-1"/>
        <variable name="outbound_caller_id_name" value="$${{outbound_caller_name}}"/>
        <variable name="outbound_caller_id_number" value="$${{outbound_caller_id}}"/>
        <variable name="sip-force-contact" value="NDLB-connectile-dysfunction"/>
        <variable name="sip-force-expires" value="7200"/>
        <variable name="X-Doma-AI-Type" value="apartment"/>
    </variables>
</user>
"""

def fs_cli(cmd):
    password = os.getenv('SOCKET_PASSWORD').strip()
    try:
        subprocess.run([
            'docker', 'compose', 'exec', '-Td', 'sip-server',
            '/usr/local/freeswitch/bin/fs_cli', '-rRS', '--password', password, '-x',
            cmd
        ])
    except Exception as e:
        print('Exception while calling fs_cli:', e)

def reload_queue(login):
    fs_cli(f"callcenter_config queue unload {login}@default")
    fs_cli(f"callcenter_config queue load {login}@default")

def reload_xml():
    print('Reloading XML...')
    fs_cli(f"reloadxml")

def transliterate(s):
    replacements = {
        'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E', 'Ё': 'Yo',
        'Ж': 'Zh', 'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M',
        'Н': 'N', 'О': 'O', 'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U',
        'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts', 'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Shch',
        'Ъ': '', 'Ы': 'Y', 'Ь': '', 'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
        'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo',
        'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
        'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
        'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch',
        'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
        ' .,;:-!?*&@#$%^()[]{}|\\\'"<>': '_',
    }
    for replace_from, replace_to in replacements.items():
        for c in replace_from:
            s = s.replace(c, replace_to)
    
    # Original script had a bug, which adds a _ to the end of the string
    return s + '_'

def import_dotenv():
    if not os.path.exists('.env'):
        return
    
    print('Importing .env...')

    with open('.env') as e:
        for line in e:
            key, value = line.split('=')
            os.environ[key.strip()] = value.strip()

def read_existing_users():
    if not os.path.exists(cc_filepath):
        return []
    
    print('Reading existing users...')
    
    with open(cc_filepath, 'r') as cc:
        content = cc.read()

    root = ET.fromstring(content)
    queues = root.findall('.//queues/queue')
    names = [q.attrib['name'].split('@')[0] for q in queues]
    
    return names

def read_input_users():
    if not os.path.isdir(input_users_dirpath):
        return []
    
    print('Reading input users...')
    
    result = {}
    for group in os.listdir(input_users_dirpath):
        fname = os.path.join(input_users_dirpath, group)
        output_fname = transliterate(os.path.splitext(group)[0])
        with open(fname) as f:
            reader = csv.DictReader(f, delimiter=';')
            result[output_fname] = list(reader)
    
    return result

def generate_configs(users):
    print('Generating configs...')
    
    queues = []
    for fname, group in users.items():
        group_users = []
        for user in group:
            if user['kvartira'] == 'x':
                user_xml = intercom_template.format(**user)
            else:
                user_xml = apartment_template.format(**user)
                queues.append(queue_template.format(**user))
            group_users.append(user_xml)

        with open(os.path.join(output_users_dirpath, fname + '.xml'), 'w') as f:
            f.write(users_teplate.format(users='\n'.join(group_users)))
    
    with open(cc_filepath, 'w') as f:
        f.write(conf_template.format(queues='\n'.join(queues)))
    
def main():
    import_dotenv()
    users = read_existing_users()
    input_users = read_input_users()

    generate_configs(input_users)
    reload_xml()
    
    new_users = {
        row['extension'] 
        for group in input_users.values() 
        for row in group 
        if row['kvartira'] != 'x'
    } - set(users)

    if not new_users:
        print('No new users')

    for new_user in new_users:
        print(new_user)
        reload_queue(new_user)

if __name__ == '__main__':
    main()