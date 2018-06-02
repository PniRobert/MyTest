DECLARE @sqlStatement nvarchar(4000), @templateCursorStatement nvarchar(4000)
DECLARE @sourceSiteId int, @targetSiteID int, @siteCode varchar(10), @templateKey varchar(255), @htmlTemplateId int, @versionNumber int, @templateData nvarchar(max)
DECLARE @culture char(5), @typeId int,  @sourceDB varchar(100), @targetDB varchar(100), @targetTemplateId int

SET @siteCode='SPLUS-APO'
SET @sourceDB = 'HTMLTemplate_Apollo_UIRefresh'
SET @targetDB = 'HTMLTemplate_Apollo_UIRefresh'

SET @sourceSiteId=NULL
SET @targetSiteID=NULL
SET @sqlStatement = 'SELECT TOP 1 @id=siteID FROM [10.211.10.155\TOSQLSTG013].[' + @sourceDB + '].dbo.[Site]  WITH(NOLOCK) WHERE siteCode=@cd'
EXEC sp_executesql @sqlStatement, N'@cd varchar(20), @id int OUTPUT', @cd=@siteCode, @id=@sourceSiteId OUTPUT
SET @sqlStatement = 'SELECT TOP 1 @id=siteID FROM [' + @targetDB + '].dbo.[Site]  WITH(NOLOCK) WHERE siteCode=@cd'
EXEC sp_executesql @sqlStatement, N'@cd varchar(20), @id int OUTPUT', @cd=@siteCode, @id=@targetSiteID OUTPUT
IF @sourceSiteId IS NOT NULL AND @targetSiteID IS NOT NULL
BEGIN
    SET @templateCursorStatement = 'DECLARE tmpCursor CURSOR FOR SELECT htmlTemplateID, templateKey FROM [10.211.10.155\TOSQLSTG013].[' + @sourceDB + '].dbo.[HtmlTemplate]  WITH(NOLOCK) WHERE siteID = ' + CAST(@sourceSiteId as varchar)
    EXEC sp_executesql @templateCursorStatement
    OPEN tmpCursor
    FETCH NEXT FROM tmpCursor INTO @htmlTemplateId, @templateKey
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF LEN(LTRIM(RTRIM(@templateKey))) > 0
        BEGIN
            SET @sqlStatement = 'SELECT TOP(1) @cu=culture, @tpId=templateTypeID, @data=templateData FROM [10.211.10.155\TOSQLSTG013].['+ @sourceDB + '].dbo.[HtmlTemplateVersion]  WITH(NOLOCK) WHERE htmlTemplateID=' + CAST(@htmlTemplateId as varchar) + ' AND publishState=''Published'' ORDER BY versionNumber DESC'
            EXEC sp_executesql @sqlStatement, N'@cu char(5) OUTPUT, @tpId int OUTPUT, @data nvarchar(max) OUTPUT', @cu=@culture OUTPUT, @tpId=@typeId OUTPUT, @data=@templateData OUTPUT
            SET @versionNumber = NULL
            SET @targetTemplateId = NULL
            SET @sqlStatement = 'SELECT @tempId=htmlTemplateID FROM [' + @targetDB + '].dbo.[HtmlTemplate] WITH(NOLOCK) WHERE siteID=' + CAST(@targetSiteID as varchar) + ' AND templateKey=''' + @templateKey + ''''
            EXEC sp_executesql @sqlStatement, N'@tempId int OUTPUT', @tempId=@targetTemplateId OUTPUT
            IF @targetTemplateId IS NULL
            BEGIN
	            SET @sqlStatement = 'INSERT INTO [' + @targetDB + '].dbo.[HtmlTemplate](uniqueID, siteID, templateKey) VALUES(NEWID(),' + CAST(@targetSiteID as varchar) + ', ''' + @templateKey  + ''')'
	            EXEC sp_executesql @sqlStatement
                SET @sqlStatement = 'SELECT @tempId=htmlTemplateID FROM [' + @targetDB + '].dbo.[HtmlTemplate] WITH(NOLOCK) WHERE siteID=' + CAST(@targetSiteID as varchar) + ' AND templateKey=''' + @templateKey + ''''
                EXEC sp_executesql @sqlStatement, N'@tempId int OUTPUT', @tempId=@targetTemplateId OUTPUT
            END
            ELSE
            BEGIN
                SET @sqlStatement =  'SELECT @vNum=MAX(versionNumber) FROM [' + @targetDB + '].dbo.[HtmlTemplateVersion] WITH(NOLOCK) WHERE htmlTemplateID=' + CAST(@targetTemplateId as varchar)
                EXEC sp_executesql @sqlStatement, N'@vNum int OUTPUT', @vNum=@versionNumber OUTPUT
            END
            IF @versionNumber IS NULL
                SET @versionNumber = 0
            ELSE 
                SET @versionNumber = @versionNumber + 1
            SET @sqlStatement = 'INSERT INTO [' + @targetDB + '].dbo.[HtmlTemplateVersion](htmlTemplateID, culture, versionNumber, templateTypeID, publishStartDate, publishState, templateData)'
            SET @sqlStatement = @sqlStatement + ' VALUES(' + CAST(@targetTemplateId as varchar) + ', ''' + @culture + ''', ' + CAST(@versionNumber as varchar) + ', ' + CAST(@typeId as varchar) + ', GETDATE(), ''Published'', @tplData)'
            --PRINT @sqlStatement
            EXEC sp_executesql @sqlStatement, N'@tplData nvarchar(max)', @tplData=@templateData
        END
        FETCH NEXT FROM tmpCursor INTO @htmlTemplateId, @templateKey
    END
    CLOSE tmpCursor
    DEALLOCATE tmpCursor
END

