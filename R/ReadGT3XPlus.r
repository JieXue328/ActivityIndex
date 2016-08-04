#' @title Read the raw tri-axial accelerometry data csv file by ActiGraph GT3X+.
#'
#' @description
#' \code{ReadGT3XPlus} reads the accelerometry data collected by ActiGraph GT3XPlus 
#' in csv files generated by ActiLife software. It automatically parses the header 
#' of the csv file to acquire the setting of the device.
#'
#' @details
#' The function is tested on the csv files generated by ActiLife6, which have exactly
#' 10 lines of headers, containing information about the device name, the starting 
#' and ending date/time of data collection, the sample rate, and the downloading date/time,
#' etc. The 11th may further be omitted, if it is the header for the tri-axial acceleration 
#' time series. The function only reads the first 3 columns from then, if more are present.
#' 
#' @param filename
#' The name of the csv file.
#' 
#' @return The \code{ReadGT3XPlus} returns an object of \link{class} "\code{GT3XPlus}". 
#' This class of object is supported by functions \code{\link{computeActivityIndex}}.
#' A object of class "\code{GT3XPlus}" is a list containing at least the following components: 
#' 
#'  \code{SN}: Serial Number of the accelerometer
#' 
#'  \code{StartTime}: Start time of the data collection
#' 
#'  \code{StartDate}: Start date of the data collection
#' 
#'  \code{Epoch}: The Epoch time of each observation. If sample rate \code{Hertz}>1, then \code{Epoch}=00:00:00
#' 
#'  \code{DownloadTime}: Download time of the data
#' 
#'  \code{DownloadDate}: Download date the data
#' 
#'  \code{Hertz}: Sampling Rate
#'
#'  \code{Raw}: a data frame with 5 columns containing the date, time and acceleration in X, Y and Z axes
#' for each observation.
#'  
#' @export
#' 
#' @import data.table
#' @import matrixStats
#' 
#' 
ReadGT3XPlus=function(filename)
{
  result=list(SN="",StartTime="",StartDate="",Epoch="",DownloadTime="",DownloadDate="",Hertz="",Raw="")
  ### Header ###
  result_Head=readLines(filename,10)
  result$Epoch=regmatches(result_Head[5],regexpr("(?<=Epoch\\sPeriod\\s\\(hh\\:mm\\:ss\\)\\s)(.+)(?=\\Z)",result_Head[5],perl=TRUE))
  result$Hertz=ifelse(length(as.numeric(regmatches(result_Head[1],regexpr("(?<=\\s)(\\d+)(?=\\sHz)",result_Head[1],perl=TRUE))))>0,
                      as.numeric(regmatches(result_Head[1],regexpr("(?<=\\s)(\\d+)(?=\\sHz)",result_Head[1],perl=TRUE))),
                      1)
  result$SN=regmatches(result_Head[2],regexpr("(?<=Serial Number:\\s)(.+)(?=\\Z)",result_Head[2],perl=TRUE))
  result$StartTime=regmatches(result_Head[3],regexpr("(?<=Start\\sTime\\s)(.+)(?=\\Z)",result_Head[3],perl=TRUE))
  result$StartDate=regmatches(result_Head[4],regexpr("(?<=Start\\sDate\\s)(.+)(?=\\Z)",result_Head[4],perl=TRUE))
  result$StartDate=as.character(as.Date(result$StartDate,format="%m/%d/%Y"))
  result$DownloadTime=regmatches(result_Head[6],regexpr("(?<=Download\\sTime\\s)(.+)(?=\\Z)",result_Head[6],perl=TRUE))
  result$DownloadDate=regmatches(result_Head[7],regexpr("(?<=Download\\sDate\\s)(.+)(?=\\Z)",result_Head[7],perl=TRUE))  
  ### Data ###
  result$Raw=read.csv(file=filename,skip=10,stringsAsFactors=FALSE,header=FALSE,nrows=1)
  if (is.character(result$Raw[,1])==TRUE)
  {
    row1=read.csv(file=filename,skip=11,stringsAsFactors=FALSE,header=FALSE,nrows=1)
    result$Raw=fread(filename,skip=11,sep=",",stringsAsFactors=FALSE,
                     colClasses=rep("numeric",ncol(row1)),header=FALSE,
                     showProgress=FALSE)
  } else
  {
    row1=read.csv(file=filename,skip=10,stringsAsFactors=FALSE,header=FALSE,nrows=1)
    result$Raw=fread(filename,skip=10,sep=",",stringsAsFactors=FALSE,
                     colClasses=rep("numeric",ncol(row1)),header=FALSE,
                     showProgress=FALSE)
  }
  # Time Stamp #
  if (as.numeric(substr(result$Epoch,7,8))<=1)
  {
    Time_Temp_idx=which(TimeScale==result$StartTime):(which(TimeScale==result$StartTime)-1+nrow(result$Raw)%/%result$Hertz+1)
    Time_Temp_idx=Time_Temp_idx%%length(TimeScale)
    Time_Temp_idx=rep(Time_Temp_idx,each=result$Hertz)
    Time_Temp_idx=Time_Temp_idx[1:nrow(result$Raw)]
    Time_Temp_idx[which(Time_Temp_idx==0)]=length(TimeScale)
  } else
  {
    Time_Temp_idx=which(TimeScale==result$StartTime):(which(TimeScale==result$StartTime)-1+nrow(result$Raw)*as.numeric(substr(result$Epoch,7,8))+1)
    Time_Temp_idx=Time_Temp_idx%%length(TimeScale)
    Time_Temp_idx=Time_Temp_idx[which((1:length(Time_Temp_idx))%%as.numeric(substr(result$Epoch,7,8))==1)]
    Time_Temp_idx=Time_Temp_idx[1:nrow(result$Raw)]
    Time_Temp_idx[which(Time_Temp_idx==0)]=length(TimeScale)
  }
  # Combine #
  result$Raw=cbind(rep(result$StartDate,nrow(result$Raw)),TimeScale[Time_Temp_idx],result$Raw)
  if (ncol(result$Raw)>5)
  {
    colnames(result$Raw)=c("Date","Time","X","Y","Z",paste0("V",1:(ncol(result$Raw)-5)))
  } else
  {
    colnames(result$Raw)=c("Date","Time","X","Y","Z")
  }
  
  # Date Stamp
  # Change the Date if sample reaches midnight
  if (length(which(result$Raw$Time=="00:00:00"))>0)
  {
    date_idx_start=which(result$Raw$Time=="00:00:00")[(1:(length(which(result$Raw$Time=="00:00:00"))%/%result$Hertz)-1)*result$Hertz+1]
    date_idx_end=c(date_idx_start[-1]-1,nrow(result$Raw))
    date_follow=as.character(as.Date(result$StartDate)+1:length(date_idx_start))
    for (i in 1:length(date_idx_start))
    {
      result$Raw$Date[date_idx_start[i]:date_idx_end[i]]=rep(date_follow[i],length(date_idx_start[i]:date_idx_end[i]))
    }  
  }
  #
  class(result)="GT3XPlus"
  return(result)
}
