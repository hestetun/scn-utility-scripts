from datetime import timedelta
import re
import pysrt
from docx import Document

def time_from_string(s):
    hours, minutes, seconds = map(int,re.split(":|;",s)[:3])
    frames = int(re.split(":|;",s)[3])
    # convert frame-rate to ms using framerate of 24 fps.
    milliseconds = int((frames/24) * 1000)

    return timedelta(hours=hours,
                     minutes=minutes,
                     seconds=seconds,
                     milliseconds=milliseconds)

# read in your .docx file 
document = Document('/Users/oah/Desktop/cobblerstreet_eng.docx')

subs = pysrt.SubRipFile()

dialogue_lines=[]
current_item=None 

for para in document.paragraphs:
   line = para.text
    
   if re.match(r"\d{4} \d\d:\d\d:\d\dd{2} \d\d:\d\dd{2}", line):  
      # New subtitle begins
      
      dialogue_number_str,start_time,end_time,*rest=line.split()
        
      start_time_td=time_from_string(start_time)
        
      end_time_td=time_from_string(end_time)
      
      if current_item: 
         current_item.text="\n".join(dialogue_lines) 
            
         subs.append(current_item) 

      dialogue_lines=[]

      current_item=pysrt.SubRipItem(
          start=start_time_td,
          end=end_time_td)

   
   elif len(line.strip())>0:   
     dialog=line.strip().split("\t\t")
     dialogue_lines.append(dialog[-1]) 


if current_item: 
    
        subs.append(current_item) 
            
subs.save('/Users/oah/Desktop/cobblerstreet_eng.srt', encoding='utf-8')