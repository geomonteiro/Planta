



    DECLARE @planType AS int
    DECLARE @Date AS Date
    DECLARE @StartDate AS DATETIME
    DECLARE @EndDate AS DATETIME
    DECLARE @EndMonth AS DATETIME
    DECLARE @CurrentDate AS DATETIME
    DECLARE @ShiftAddMinutesStartPeriod INT 
    DECLARE @ShiftAddMinutesEndPeriod INT
    DECLARE @StartDateIndex AS DATETIME
    DECLARE @EndDateIndex AS DATETIME
    --, MoagemToneladasUmidas FLOAT
    DECLARE @tblTeores	TABLE(PeriodIndex DATETIME, MoagemUmidade FLOAT, MoagemToneladasSecas FLOAT, Concentrado FLOAT, TeorAlimentacaoCobre FLOAT, TeorAlimentacaoOuro FLOAT, TeorAlimentacaoEnxofre FLOAT, TeorCFColunaCobre FLOAT, TeorCFColunaOuro FLOAT, TeorRejeitoCobre FLOAT, TeorRejeitoOuro FLOAT, P80Flotacao FLOAT)
    DECLARE @tblPeriod	TABLE(PeriodIndex DATETIME, StartPeriod DATETIME, EndPeriod DATETIME, HorasCalendario FLOAT)

    DECLARE @tblKPIsDowntimeIPC    TABLE(AreaDTM VARCHAR(50), PeriodIndex DATETIME, KPIType VARCHAR(50), KPIOrder VARCHAR(10), KPIDescription VARCHAR(200), KPIValue FLOAT, KPITarget FLOAT)
    DECLARE @tblKPIsDowntimeMMD    TABLE(AreaDTM VARCHAR(50), PeriodIndex DATETIME, KPIType VARCHAR(50), KPIOrder VARCHAR(10), KPIDescription VARCHAR(200), KPIValue FLOAT, KPITarget FLOAT)
    DECLARE @tblKPIsDowntimeC160    TABLE(AreaDTM VARCHAR(50), PeriodIndex DATETIME, KPIType VARCHAR(50), KPIOrder VARCHAR(10), KPIDescription VARCHAR(200), KPIValue FLOAT, KPITarget FLOAT)
    DECLARE @tblKPIsDowntimeMoagem    TABLE(AreaDTM VARCHAR(50), PeriodIndex DATETIME, KPIType VARCHAR(50), KPIOrder VARCHAR(10), KPIDescription VARCHAR(200), KPIValue FLOAT, KPITarget FLOAT)

    DECLARE @IpcNominalProductionRate AS FLOAT
    DECLARE @MmdNominalProductionRate AS FLOAT
    DECLARE @MandibulasNominalProductionRate AS FLOAT
    DECLARE @MoagemNominalProductionRate AS FLOAT

    --Correção dee Teores pelo Ajuste de Estoque
    DECLARE @fatorAuAlimentacao NUMERIC(38,18), @fatorCuAlimentacao NUMERIC(38,18), @fatorCuColuna NUMERIC(38,18), @fatorAuColuna NUMERIC(38,18)


    BEGIN
    SET @Date = ?

    SET NOCOUNT ON;

        SET @IpcNominalProductionRate = [dbo].[custom_GetAreaNominalRate]('310 BRITAGEM IPC', @Date) --(SELECT TOP 1 [AREA_NOMINAL_PRODUCTION_RATE] FROM [dbo].[TBL_KPI_AREA] WHERE [AREA_NAME] = 'IPC')
        SET @MmdNominalProductionRate = [dbo].[custom_GetAreaNominalRate]('310 BRITAGEM MMD', @Date) --(SELECT TOP 1 [AREA_NOMINAL_PRODUCTION_RATE] FROM [dbo].[TBL_KPI_AREA] WHERE [AREA_NAME] = 'MMD')
        SET @MandibulasNominalProductionRate = [dbo].[custom_GetAreaNominalRate]('310 BRITAGEM C160', @Date) --(SELECT TOP 1 [AREA_NOMINAL_PRODUCTION_RATE] FROM [dbo].[TBL_KPI_AREA] WHERE [AREA_NAME] = 'Mandíbulas')
        SET @MoagemNominalProductionRate = [dbo].[custom_GetAreaNominalRate]('330 MOAGEM', @Date) --(SELECT TOP 1 [AREA_NOMINAL_PRODUCTION_RATE] FROM [dbo].[TBL_KPI_AREA] WHERE [AREA_NAME] = 'Moagem')
        
        
        SELECT
            @fatorAuAlimentacao = COALESCE(CDL_NUMBER_00008, 0),
            @fatorCuAlimentacao = COALESCE(CDL_NUMBER_00009, 0),
            @fatorAuColuna = COALESCE(CDL_NUMBER_00011, 0),
            @fatorCuColuna = COALESCE(CDL_NUMBER_00010, 0)
        FROM TBL_GPROD_OBJ_27
        WHERE
        CDL_NUMBER_00001 = DATEPART(MONTH, @Date)
        AND
        CDL_NUMBER_00002 = DATEPART(YEAR, @Date)
        
        SET @EndDateIndex = CAST(CAST(@Date AS DATE) AS DATETIME)
        SET @StartDate = CONVERT(DATETIME, CONVERT(VARCHAR(4), YEAR(@Date)) + '-' + CONVERT(VARCHAR(2), MONTH(@Date))  + '-01', 120)
        SET @EndDate = DATEADD(DD, 1, CAST(CAST(@Date AS DATE) AS DATETIME))
        SET @EndMonth = DATEADD(MM, 1, @StartDate)
        
        SET @StartDateIndex = @StartDate
        SET @EndDateIndex = @EndDate
        
        DELETE FROM @tblPeriod
        SET @currentDate = @StartDate
        WHILE @currentDate < @EndMonth
        BEGIN
            SET @ShiftAddMinutesStartPeriod = (SELECT TOP 1 [SHIFT_ADD_MINUTES_START] FROM [dbo].[TBL_SHIFTS] WHERE SHIFT_ORDER_SHT = 1 AND DATE_EFFECTED < @CurrentDate ORDER BY [DATE_EFFECTED] DESC, [SHIFT_ORDER_SHT] ASC)
            SET @ShiftAddMinutesEndPeriod = (SELECT TOP 1 [SHIFT_ADD_MINUTES_START] FROM [dbo].[TBL_SHIFTS] WHERE SHIFT_ORDER_SHT = 1 AND DATE_EFFECTED < DATEADD(DD,1,@CurrentDate) ORDER BY [DATE_EFFECTED] DESC, [SHIFT_ORDER_SHT] ASC)
            INSERT INTO @tblPeriod (PeriodIndex, StartPeriod, EndPeriod, HorasCalendario) 
            VALUES (@currentDate, DATEADD(MI, @ShiftAddMinutesStartPeriod, @CurrentDate), DATEADD(MI, @ShiftAddMinutesEndPeriod, DATEADD(DD, 1, @currentDate)), (DATEDIFF(MI, DATEADD(MI, @ShiftAddMinutesStartPeriod, @CurrentDate), DATEADD(MI, @ShiftAddMinutesEndPeriod, DATEADD(DD, 1, @currentDate))) / 60.0))
            SET @currentDate = DATEADD(DD, 1, @currentDate)			
        END
        
        SELECT TOP 1 @StartDate = DATEADD(MI, [SHIFT_ADD_MINUTES_START], @StartDate) 	
            FROM [dbo].[TBL_SHIFTS] WHERE SHIFT_ORDER_SHT = 1 AND DATE_EFFECTED < @StartDate 
            ORDER BY [DATE_EFFECTED] DESC, [SHIFT_ORDER_SHT] ASC
        
        
        SELECT TOP 1 @EndDate = DATEADD(MI, [SHIFT_ADD_MINUTES_START], @EndDate)	
            FROM [dbo].[TBL_SHIFTS] WHERE SHIFT_ORDER_SHT = 1 AND DATE_EFFECTED < @EndDate 
            ORDER BY [DATE_EFFECTED] DESC, [SHIFT_ORDER_SHT] ASC
        
        DELETE FROM @tblTeores
        INSERT INTO @tblTeores(PeriodIndex, MoagemUmidade, MoagemToneladasSecas, Concentrado, P80Flotacao)--, MoagemToneladasUmidas
        SELECT [TBL_GPROD_OBJ_4].CDL_DATETIME_00001
            --, ISNULL(NULLIF([TBL_GPROD_OBJ_4].[CDL_NUMBER_00012], -999), 0.0) 
            , ISNULL(NULLIF([TBL_GPROD_OBJ_2].CDL_NUMBER_00002, -999), 5.0)
            , ISNULL(NULLIF([TBL_GPROD_OBJ_4].CDL_NUMBER_00012, -999), 0.0) * (1.0 - ISNULL(NULLIF([TBL_GPROD_OBJ_2].CDL_NUMBER_00002, -999), 5.0) / 100.0)
            , ISNULL(NULLIF([TBL_GPROD_OBJ_5].[CDL_NUMBER_00012], -999), 0.0)
            , NULLIF([TBL_GPROD_OBJ_3].[CDL_NUMBER_00009], -999)
        FROM [dbo].[TBL_GPROD_OBJ_4] 
        INNER JOIN [dbo].[TBL_GPROD_OBJ_3] ON ([TBL_GPROD_OBJ_4].CDL_DATETIME_00001 = [TBL_GPROD_OBJ_3].CDL_DATETIME_00001)
        INNER JOIN [dbo].[TBL_GPROD_OBJ_5] ON ([TBL_GPROD_OBJ_4].CDL_DATETIME_00001 = [TBL_GPROD_OBJ_5].CDL_DATETIME_00001) 
        --INNER JOIN [dbo].[TBL_GPROD_OBJ_32] ON ([TBL_GPROD_OBJ_4].[CDL_DATETIME_00002] = [TBL_GPROD_OBJ_32].[CDL_DATETIME_00001])
        INNER JOIN [dbo].[TBL_GPROD_OBJ_2] ON ([TBL_GPROD_OBJ_4].CDL_DATETIME_00001 = [TBL_GPROD_OBJ_2].CDL_DATETIME_00001)
        WHERE [TBL_GPROD_OBJ_4].CDL_DATETIME_00001 >= @StartDate AND [TBL_GPROD_OBJ_4].CDL_DATETIME_00001 < @EndDate
        AND [TBL_GPROD_OBJ_3].CDL_DATETIME_00001 >= @StartDate AND [TBL_GPROD_OBJ_3].CDL_DATETIME_00001 < @EndDate
        AND [TBL_GPROD_OBJ_5].CDL_DATETIME_00001 >= @StartDate AND [TBL_GPROD_OBJ_5].CDL_DATETIME_00001 < @EndDate
        --AND [TBL_GPROD_OBJ_32].CDL_DATETIME_00001 >= @StartDateIndex AND [TBL_GPROD_OBJ_32].CDL_DATETIME_00001 < @EndDateIndex
        AND [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 >= @StartDate AND [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 < @EndDate
        AND [TBL_GPROD_OBJ_2].CDL_NUMBER_00001 = 4
        AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR50_00001)) = 'Moagem'
        AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR100_00001)) = 'Umidade Minério'
        
        UPDATE @tblTeores 
        SET TeorAlimentacaoCobre = (1.0+@fatorCuAlimentacao/100.0) * COALESCE(NULLIF([TBL_GPROD_OBJ_2].CDL_NUMBER_00002, -999),
                        (SELECT TOP 1 BEFOREVALUE.CDL_NUMBER_00002 
                        FROM [dbo].[TBL_GPROD_OBJ_2] BEFOREVALUE
                        WHERE BEFOREVALUE.CDL_DATETIME_00001 > DATEADD(MM, -1, @StartDate)
                                AND BEFOREVALUE.CDL_DATETIME_00001 < [TBL_GPROD_OBJ_2].CDL_DATETIME_00001        
                                AND BEFOREVALUE.CDL_NUMBER_00002 <> -999 
                                AND BEFOREVALUE.CDL_NUMBER_00002 IS NOT NULL
                                AND BEFOREVALUE.CDL_NUMBER_00001 = 8
                                AND RTRIM(LTRIM(BEFOREVALUE.CDL_STR50_00001)) = 'Alimentação Sag'
                                AND RTRIM(LTRIM(BEFOREVALUE.CDL_STR100_00001)) = 'Cu'
                        ORDER BY BEFOREVALUE.CDL_DATETIME_00001 DESC))
        FROM @tblTeores 
        INNER JOIN [dbo].[TBL_GPROD_OBJ_2] ON ([@tblTeores].PeriodIndex = [TBL_GPROD_OBJ_2].CDL_DATETIME_00001)
        WHERE [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 >= @StartDate AND [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 < @EndDate
            AND [TBL_GPROD_OBJ_2].CDL_NUMBER_00001 = 8
            AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR50_00001)) = 'Alimentação Sag'
            AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR100_00001)) = 'Cu'
        

        UPDATE @tblTeores 
        SET TeorAlimentacaoOuro = (1.0+@fatorAuAlimentacao/100.0) * COALESCE(NULLIF([TBL_GPROD_OBJ_2].CDL_NUMBER_00002, -999),
                        (SELECT TOP 1 BEFOREVALUE.CDL_NUMBER_00002 
                        FROM [dbo].[TBL_GPROD_OBJ_2] BEFOREVALUE
                        WHERE BEFOREVALUE.CDL_DATETIME_00001 > DATEADD(MM, -1, @StartDate)
                                AND BEFOREVALUE.CDL_DATETIME_00001 < [TBL_GPROD_OBJ_2].CDL_DATETIME_00001        
                                AND BEFOREVALUE.CDL_NUMBER_00002 <> -999 
                                AND BEFOREVALUE.CDL_NUMBER_00002 IS NOT NULL
                                AND BEFOREVALUE.CDL_NUMBER_00001 = 8
                                AND RTRIM(LTRIM(BEFOREVALUE.CDL_STR50_00001)) = 'Alimentação Sag'
                                AND RTRIM(LTRIM(BEFOREVALUE.CDL_STR100_00001)) = 'Au'
                        ORDER BY BEFOREVALUE.CDL_DATETIME_00001 DESC))			  
        FROM @tblTeores 
        INNER JOIN [dbo].[TBL_GPROD_OBJ_2] ON ([@tblTeores].PeriodIndex = [TBL_GPROD_OBJ_2].CDL_DATETIME_00001)
        WHERE [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 >= @StartDate AND [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 < @EndDate
            AND [TBL_GPROD_OBJ_2].CDL_NUMBER_00001 = 8
            AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR50_00001)) = 'Alimentação Sag'
            AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR100_00001)) = 'Au'
        
        UPDATE @tblTeores 
        SET TeorAlimentacaoEnxofre = COALESCE(NULLIF([TBL_GPROD_OBJ_2].CDL_NUMBER_00002, -999),
                        (SELECT TOP 1 BEFOREVALUE.CDL_NUMBER_00002 
                        FROM [dbo].[TBL_GPROD_OBJ_2] BEFOREVALUE
                        WHERE BEFOREVALUE.CDL_DATETIME_00001 > DATEADD(MM, -1, @StartDate)
                                AND BEFOREVALUE.CDL_DATETIME_00001 < [TBL_GPROD_OBJ_2].CDL_DATETIME_00001        
                                AND BEFOREVALUE.CDL_NUMBER_00002 <> -999 
                                AND BEFOREVALUE.CDL_NUMBER_00002 IS NOT NULL
                                AND BEFOREVALUE.CDL_NUMBER_00001 = 8
                                AND RTRIM(LTRIM(BEFOREVALUE.CDL_STR50_00001)) = 'Alimentação Sag'
                                AND RTRIM(LTRIM(BEFOREVALUE.CDL_STR100_00001)) = 'S'
                        ORDER BY BEFOREVALUE.CDL_DATETIME_00001 DESC))			  
        FROM @tblTeores 
        INNER JOIN [dbo].[TBL_GPROD_OBJ_2] ON ([@tblTeores].PeriodIndex = [TBL_GPROD_OBJ_2].CDL_DATETIME_00001)
        WHERE [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 >= @StartDate AND [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 < @EndDate
            AND [TBL_GPROD_OBJ_2].CDL_NUMBER_00001 = 8
            AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR50_00001)) = 'Alimentação Sag'
            AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR100_00001)) = 'S'
                
        UPDATE @tblTeores 
        SET TeorCFColunaCobre = (1.0+@fatorCuColuna/100.0) * COALESCE(NULLIF([TBL_GPROD_OBJ_2].CDL_NUMBER_00002, -999),
                        (SELECT TOP 1 BEFOREVALUE.CDL_NUMBER_00002 
                        FROM [dbo].[TBL_GPROD_OBJ_2] BEFOREVALUE
                        WHERE BEFOREVALUE.CDL_DATETIME_00001 > DATEADD(MM, -1, @StartDate)
                                AND BEFOREVALUE.CDL_DATETIME_00001 < [TBL_GPROD_OBJ_2].CDL_DATETIME_00001        
                                AND BEFOREVALUE.CDL_NUMBER_00002 <> -999 
                                AND BEFOREVALUE.CDL_NUMBER_00002 IS NOT NULL
                                AND BEFOREVALUE.CDL_NUMBER_00001 = 3
                                AND RTRIM(LTRIM(BEFOREVALUE.CDL_STR50_00001)) = 'Concentrado Coluna'
                                AND RTRIM(LTRIM(BEFOREVALUE.CDL_STR100_00001)) = 'Cu'
                        ORDER BY BEFOREVALUE.CDL_DATETIME_00001 DESC))
        FROM @tblTeores 
        INNER JOIN [dbo].[TBL_GPROD_OBJ_2] ON ([@tblTeores].PeriodIndex = [TBL_GPROD_OBJ_2].CDL_DATETIME_00001)
        WHERE [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 >= @StartDate AND [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 < @EndDate
            AND [TBL_GPROD_OBJ_2].CDL_NUMBER_00001 = 3
            AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR50_00001)) = 'Concentrado Coluna'
            AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR100_00001)) = 'Cu'
        

        UPDATE @tblTeores 
        SET TeorCFColunaOuro = (1.0 + @fatorAuColuna / 100.0) * COALESCE(NULLIF([TBL_GPROD_OBJ_2].CDL_NUMBER_00002, -999),
                        (SELECT TOP 1 BEFOREVALUE.CDL_NUMBER_00002 
                        FROM [dbo].[TBL_GPROD_OBJ_2] BEFOREVALUE
                        WHERE BEFOREVALUE.CDL_DATETIME_00001 > DATEADD(MM, -1, @StartDate)
                                AND BEFOREVALUE.CDL_DATETIME_00001 < [TBL_GPROD_OBJ_2].CDL_DATETIME_00001        
                                AND BEFOREVALUE.CDL_NUMBER_00002 <> -999 
                                AND BEFOREVALUE.CDL_NUMBER_00002 IS NOT NULL
                                AND BEFOREVALUE.CDL_NUMBER_00001 = 3
                                AND RTRIM(LTRIM(BEFOREVALUE.CDL_STR50_00001)) = 'Concentrado Coluna'
                                AND RTRIM(LTRIM(BEFOREVALUE.CDL_STR100_00001)) = 'Au'
                        ORDER BY BEFOREVALUE.CDL_DATETIME_00001 DESC))
        FROM @tblTeores 
        INNER JOIN [dbo].[TBL_GPROD_OBJ_2] ON ([@tblTeores].PeriodIndex = [TBL_GPROD_OBJ_2].CDL_DATETIME_00001)
        WHERE [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 >= @StartDate AND [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 < @EndDate
            AND [TBL_GPROD_OBJ_2].CDL_NUMBER_00001 = 3
            AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR50_00001)) = 'Concentrado Coluna'
            AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR100_00001)) = 'Au'
        
            
        UPDATE @tblTeores 
        SET TeorRejeitoCobre = COALESCE(NULLIF([TBL_GPROD_OBJ_2].CDL_NUMBER_00002, -999),
                        (SELECT TOP 1 BEFOREVALUE.CDL_NUMBER_00002 
                        FROM [dbo].[TBL_GPROD_OBJ_2] BEFOREVALUE
                        WHERE BEFOREVALUE.CDL_DATETIME_00001 > DATEADD(MM, -1, @StartDate)
                                AND BEFOREVALUE.CDL_DATETIME_00001 < [TBL_GPROD_OBJ_2].CDL_DATETIME_00001        
                                AND BEFOREVALUE.CDL_NUMBER_00002 <> -999 
                                AND BEFOREVALUE.CDL_NUMBER_00002 IS NOT NULL
                                AND BEFOREVALUE.CDL_NUMBER_00001 = 7
                                AND RTRIM(LTRIM(BEFOREVALUE.CDL_STR50_00001)) = 'Rejeito Final'
                                AND RTRIM(LTRIM(BEFOREVALUE.CDL_STR100_00001)) = 'Cu'
                        ORDER BY BEFOREVALUE.CDL_DATETIME_00001 DESC))
        FROM @tblTeores 
        INNER JOIN [dbo].[TBL_GPROD_OBJ_2] ON ([@tblTeores].PeriodIndex = [TBL_GPROD_OBJ_2].CDL_DATETIME_00001)
        WHERE [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 >= @StartDate AND [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 < @EndDate
            AND [TBL_GPROD_OBJ_2].CDL_NUMBER_00001 = 7
            AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR50_00001)) = 'Rejeito Final'
            AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR100_00001)) = 'Cu'
        
            
        UPDATE @tblTeores 
        SET TeorRejeitoOuro = COALESCE(dbo.custom_fn_CheckInvalidValueCalc([TBL_GPROD_OBJ_2].CDL_NUMBER_00002),
                        (SELECT TOP 1 BEFOREVALUE.CDL_NUMBER_00002 
                        FROM [dbo].[TBL_GPROD_OBJ_2] BEFOREVALUE
                        WHERE BEFOREVALUE.CDL_DATETIME_00001 > DATEADD(MM, -1, @StartDate)
                                AND BEFOREVALUE.CDL_DATETIME_00001 <= [TBL_GPROD_OBJ_2].CDL_DATETIME_00001        
                                AND BEFOREVALUE.CDL_NUMBER_00002 <> -999 
                                AND BEFOREVALUE.CDL_NUMBER_00002 IS NOT NULL
                                AND BEFOREVALUE.CDL_NUMBER_00001 = 7
                                AND RTRIM(LTRIM(BEFOREVALUE.CDL_STR50_00001)) = 'Rejeito Final'
                                AND RTRIM(LTRIM(BEFOREVALUE.CDL_STR100_00001)) = 'Au'
                        ORDER BY BEFOREVALUE.CDL_DATETIME_00001 DESC))
        FROM @tblTeores 
        INNER JOIN [dbo].[TBL_GPROD_OBJ_2] ON ([@tblTeores].PeriodIndex = [TBL_GPROD_OBJ_2].CDL_DATETIME_00001)
        WHERE [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 >= @StartDate AND [TBL_GPROD_OBJ_2].CDL_DATETIME_00001 < @EndDate
            AND [TBL_GPROD_OBJ_2].CDL_NUMBER_00001 = 7
            AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR50_00001)) = 'Rejeito Final'
            AND RTRIM(LTRIM([TBL_GPROD_OBJ_2].CDL_STR100_00001)) = 'Au'
            
        SET @CurrentDate = CAST(CAST(@Date AS DATE) AS DATETIME)
        
        DELETE FROM @tblKPIsDowntimeIPC
        INSERT INTO @tblKPIsDowntimeIPC(AreaDTM, PeriodIndex, KPIType, KPIOrder, KPIDescription, KPIValue, KPITarget)
        EXEC custom_DowntimeKPIGroupByAreaAndPeriod @StartDateIndex, @CurrentDate, '310 BRITAGEM IPC', 'Day', @planType, 0
        
        DELETE FROM @tblKPIsDowntimeMMD
        INSERT INTO @tblKPIsDowntimeMMD(AreaDTM, PeriodIndex, KPIType, KPIOrder, KPIDescription, KPIValue, KPITarget)
        EXEC custom_DowntimeKPIGroupByAreaAndPeriod @StartDateIndex, @CurrentDate, '310 BRITAGEM MMD', 'Day', @planType, 0
        
        DELETE FROM @tblKPIsDowntimeC160
        INSERT INTO @tblKPIsDowntimeC160(AreaDTM, PeriodIndex, KPIType, KPIOrder, KPIDescription, KPIValue, KPITarget)
        EXEC custom_DowntimeKPIGroupByAreaAndPeriod @StartDateIndex, @CurrentDate, '310 BRITAGEM C160', 'Day', @planType, 0
        
        DELETE FROM @tblKPIsDowntimeMoagem
        INSERT INTO @tblKPIsDowntimeMoagem(AreaDTM, PeriodIndex, KPIType, KPIOrder, KPIDescription, KPIValue, KPITarget)
        EXEC custom_DowntimeKPIGroupByAreaAndPeriod @StartDateIndex, @CurrentDate, '330 MOAGEM', 'Day', @planType, 0
        
        
        --############# Display Rsults #################
        SELECT [@tblPeriod].PeriodIndex
        --Real
        , CAST(ISNULL(AlimentacaoIPCReal, 0.0) AS FLOAT) AS AlimentacaoIpcReal
        , CAST(ISNULL(AlimentacaoMMDReal, 0.0) AS FLOAT) AS AlimentacaoMmdReal
        , CAST(ISNULL(AlimentacaoC160Real, 0.0) AS FLOAT) AS AlimentacaoMandibulasReal
        , CAST(ISNULL(AlimentacaoBritagensReal, 0.0) AS FLOAT) AS AlimentacaoBritagensReal
        , CAST(ISNULL(AlimentacaoPlantaReal, 0.0) AS FLOAT) AS AlimentacaoPlantaReal
        , P80FlotacaoReal
        , TeorAlimentacaoCobreReal
        , TeorAlimentacaoOuroReal
        , (NULLIF(TeorAlimentacaoEnxofreReal, -999)-(NULLIF(TeorAlimentacaoCobreReal, -999)/34.63)*34.94)/53.45*100 AS TeorAlimentacaoPiritaReal
        , TeorConcentradoCobreReal
        , TeorConcentradoOuroReal
        , TeorRejeitoCobreReal
        , TeorRejeitoOuroReal
        , 100.0 * RecuperacaoCobreReal AS RecuperacaoCobreReal 
        , 100.0 * RecuperacaoOuroReal AS RecuperacaoOuroReal
        , (AlimentacaoPlantaReal * TeorAlimentacaoCobreReal / 100.0) AS CobreContidoReal 
        , (AlimentacaoPlantaReal * TeorAlimentacaoOuroReal) / 1000.0 AS OuroContidoReal
        --, ((AlimentacaoPlantaReal * (TeorAlimentacaoCobreReal / 100.0) * RecuperacaoCobreReal) / NULLIF((TeorConcentradoCobreReal / 100.0), 0.0)) AS MassaConcentradoReal
        , ConcentradoReal AS MassaConcentradoReal
        , ProducaoPrataOzReal
        , (AlimentacaoPlantaReal * TeorAlimentacaoOuroReal * RecuperacaoOuroReal) / 31.1034768 AS ProducaoOuroOzReal
        , ((AlimentacaoPlantaReal * TeorAlimentacaoOuroReal * RecuperacaoOuroReal) / 31.1034768) + ProducaoPrataOzReal / 50.0 AS ProducaoOuroGEOReal
        , ((AlimentacaoPlantaReal * (TeorAlimentacaoCobreReal / 100.0) * RecuperacaoCobreReal) / 0.453592370380378) AS ProducaoCobreKLBReal
        , (AlimentacaoPlantaReal * TeorAlimentacaoOuroReal * RecuperacaoOuroReal) / 1000.0 AS ProducaoOuroKgReal
        , AlimentacaoPlantaReal * (TeorAlimentacaoCobreReal / 100.0) * RecuperacaoCobreReal AS ProducaoCobreTonReal
        , CAST(100.0 * DisponibilidadePlantaReal AS FLOAT) AS DisponibilidadePlantaReal
        , CAST(100.0 * UtilizacaoPlantaReal AS FLOAT) AS UtilizacaoPlantaReal
        , CAST(AlimentacaoPlantaReal / NULLIF(HorasUtilizadasPlantaReal, 0.0) AS FLOAT) AS ProdutividadePlantaReal
        , HorasParadasProgramadasReal 
        , HorasParadasManutencaoReal 
        , HorasParadasOperacaoReal 
        , HorasParadasExternoReal
        , CAST(HorasDisponiveisPlantaReal AS FLOAT) AS HorasDisponiveisPlantaReal
        , CAST(HorasUtilizadasPlantaReal AS FLOAT) AS HorasUtilizadasPlantaReal
        , CAST(100.0 * AlimentacaoPlantaReal / [@tblPeriod].HorasCalendario / @MoagemNominalProductionRate AS FLOAT) AS OeePlantaReal
        
        , CAST(HorasUtilizadasIPCReal AS FLOAT) AS HorasUtilizadasIpcReal
        , CAST(HorasDisponiveisIPCReal AS FLOAT) AS HorasDisponiveisIpcReal
        , CAST(100.0 * HorasDisponiveisIPCReal / [@tblPeriod].HorasCalendario AS FLOAT) AS DisponibilidadeIpcReal
        , CAST(100.0 * HorasUtilizadasIPCReal / NULLIF(HorasDisponiveisIPCReal, 0.0) AS FLOAT) AS UtilizacaoIpcReal
        , CAST(AlimentacaoIPCReal / NULLIF(HorasUtilizadasIPCReal, 0.0) AS FLOAT) AS ProdutividadeIpcReal
        , CAST(100.0 * AlimentacaoIPCReal / [@tblPeriod].HorasCalendario / @IpcNominalProductionRate AS FLOAT) AS OeeIpcReal
        
        , CAST(HorasUtilizadasMMDReal AS FLOAT) AS HorasUtilizadasMmdReal
        , CAST(HorasDisponiveisMMDReal AS FLOAT) AS HorasDisponiveisMmdReal
        , CAST(100.0 * DisponibilidadeMMDReal AS FLOAT) AS DisponibilidadeMmdReal
        , CAST(100.0 * UtilizacaoMMDReal AS FLOAT) AS UtilizacaoMmdReal
        , CAST(AlimentacaoMMDReal / NULLIF(HorasUtilizadasMMDReal, 0.0) AS FLOAT) AS ProdutividadeMmdReal
        , CAST(100.0 * AlimentacaoMMDReal / [@tblPeriod].HorasCalendario / @MmdNominalProductionRate AS FLOAT) AS OeeMmdReal
        
        , CAST(HorasUtilizadasC160Real AS FLOAT) AS HorasUtilizadasMandibulasReal
        , CAST(HorasDisponiveisC160Real AS FLOAT) AS HorasDisponiveisMandibulasReal
        , CAST(100.0 * DisponibilidadeC160Real AS FLOAT) AS DisponibilidadeMandibulasReal
        , CAST(100.0 * UtilizacaoC160Real AS FLOAT) AS UtilizacaoMandibulasReal
        , CAST(AlimentacaoC160Real / NULLIF(HorasUtilizadasC160Real, 0.0) AS FLOAT) AS ProdutividadeMandibulasReal
        , CAST(100.0 * AlimentacaoC160Real / [@tblPeriod].HorasCalendario / @MandibulasNominalProductionRate AS FLOAT) AS OeeMandibulasReal
        
        , CAST((HorasUtilizadasMMDReal + HorasUtilizadasC160Real) AS FLOAT) AS HorasUtilizadasBritagensReal
        , CAST((HorasDisponiveisMMDReal + HorasDisponiveisC160Real) AS FLOAT) AS HorasDisponiveisBritagensReal
        , CAST(100.0 * (HorasDisponiveisMMDReal + HorasDisponiveisC160Real) / 48.0 AS FLOAT) AS DisponibilidadeBritagensReal
        , CAST(100.0 * (HorasUtilizadasMMDReal + HorasUtilizadasC160Real) / NULLIF((HorasDisponiveisMMDReal + HorasDisponiveisC160Real), 0.0) AS FLOAT) AS UtilizacaoBritagensReal
        , CAST(AlimentacaoBritagensReal / NULLIF((HorasUtilizadasMMDReal + HorasUtilizadasC160Real), 0.0) AS FLOAT) AS ProdutividadeBritagensReal
        , CAST(100.0 * (AlimentacaoMMDReal + AlimentacaoC160Real) / [@tblPeriod].HorasCalendario / (@MmdNominalProductionRate + @MandibulasNominalProductionRate) AS FLOAT) AS OeeBritagensReal
        
        --Orcado ou Forcast
        , CAST(ISNULL(AlimentacaoIPCOrcado, 0.0) AS FLOAT) AS AlimentacaoIpcOrcado
        , CAST(ISNULL(AlimentacaoMMDOrcado, 0.0) AS FLOAT) AS AlimentacaoMmdOrcado
        , CAST(ISNULL(AlimentacaoC160Orcado, 0.0) AS FLOAT) AS AlimentacaoMandibulasOrcado
        , CAST((ISNULL(AlimentacaoMMDOrcado, 0.0) + ISNULL(AlimentacaoC160Orcado, 0.0)) AS FLOAT) AS AlimentacaoBritagensOrcado 
        , CAST(ISNULL(AlimentacaoPlantaOrcado, 0.0) AS FLOAT) AS AlimentacaoPlantaOrcado
        , CAST(ISNULL(TeorAlimentacaoCobreOrcado, 0.0) AS FLOAT) AS TeorAlimentacaoCobreOrcado
        , CAST(ISNULL(TeorAlimentacaoOuroOrcado, 0.0) AS FLOAT) AS TeorAlimentacaoOuroOrcado
        , CAST(ISNULL(TeorConcentradoCobreOrcado, 0.0) AS FLOAT) AS TeorConcentradoCobreOrcado
        , CAST(ISNULL(TeorConcentradoOuroOrcado, 0.0) AS FLOAT) AS TeorConcentradoOuroOrcado
        , CAST(ISNULL(100.0 * (TeorAlimentacaoCobreOrcado / 100.0) * (TeorConcentradoCobreOrcado / 100.0) * ((RecuperacaoCobreOrcado / 100.0) - 1.0) / NULLIF(((RecuperacaoCobreOrcado / 100.0) * (TeorAlimentacaoCobreOrcado / 100.0) - (TeorConcentradoCobreOrcado / 100.0)), 0.0), 0.0) AS FLOAT) AS TeorRejeitoCobreOrcado
        , CAST(ISNULL((TeorAlimentacaoOuroOrcado) * (TeorConcentradoOuroOrcado) * ((RecuperacaoOuroOrcado / 100.0) - 1.0) / NULLIF(((RecuperacaoOuroOrcado / 100.0) * (TeorAlimentacaoOuroOrcado) - (TeorConcentradoOuroOrcado)), 0.0), 0.0) AS FLOAT) AS TeorRejeitoOuroOrcado
        , CAST(ISNULL(RecuperacaoCobreOrcado, 0.0) AS FLOAT)  AS RecuperacaoCobreOrcado
        , CAST(ISNULL(RecuperacaoOuroOrcado, 0.0) AS FLOAT)  AS RecuperacaoOuroOrcado
        , CAST(ISNULL(CobreContidoOrcado, 0.0) AS FLOAT)  AS CobreContidoOrcado
        , CAST(ISNULL(OuroContidoOrcado, 0.0) AS FLOAT) AS OuroContidoOrcado
        , CAST(ISNULL(MassaConcentradoOrcado, 0.0) AS FLOAT) AS MassaConcentradoOrcado
        , CAST(ISNULL(ProducaoPrataOzOrcado, 0.0) AS FLOAT) AS ProducaoPrataOzOrcado
        , CAST(ISNULL(ProducaoOuroOzOrcado, 0.0) AS FLOAT) AS ProducaoOuroOzOrcado
        , CAST(ISNULL(ProducaoOuroGEOOrcado, 0.0) AS FLOAT) AS ProducaoOuroGEOOrcado
        , CAST(ISNULL(ProducaoCobreKLBOrcado, 0.0) AS FLOAT) AS ProducaoCobreKLBOrcado
        , CAST(ISNULL(ProducaoOuroKgOrcado, 0.0) AS FLOAT) AS ProducaoOuroKgOrcado
        , CAST(ISNULL(ProducaoCobreTonOrcado, 0.0) AS FLOAT) AS ProducaoCobreTonOrcado
        , CAST(ISNULL(DisponibilidadePlantaOrcado, 0.0) AS FLOAT) AS DisponibilidadePlantaOrcado
        , CAST(ISNULL(UtilizacaoPlantaOrcado, 0.0) AS FLOAT) AS UtilizacaoPlantaOrcado
        , CAST(ISNULL(ProdutividadePlantaOrcado, 0.0) AS FLOAT) AS ProdutividadePlantaOrcado
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (1.0 - DisponibilidadePlantaOrcado / 100.0) * (ISNULL(ProporcManutProgramadaOrcado, 100.0) / 100.0), 0.0) AS FLOAT)  AS HorasParadasProgramadasOrcado 
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (1.0 - DisponibilidadePlantaOrcado / 100.0) * (ISNULL(ProporcManutCorretivaOrcado, 0.0) / 100.0), 0.0) AS FLOAT)  AS HorasParadasManutencaoOrcado 
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (1.0 - DisponibilidadePlantaOrcado / 100.0) * (ISNULL(ProporcManutCorretivaOrcado, 0.0) / 100.0) * (ISNULL(ProporcManutExternoOrcado, 0.0) / 100.0), 0.0) AS FLOAT)  AS HorasParadasExternoOrcado
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadePlantaOrcado / 100.0) * (1.0 - UtilizacaoPlantaOrcado / 100.0), 0.0) AS FLOAT) AS HorasParadasOperacaoOrcado 
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadePlantaOrcado / 100.0), 0.0) AS FLOAT)  AS HorasDisponiveisPlantaOrcado 
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadePlantaOrcado / 100.0) * (UtilizacaoPlantaOrcado / 100.0), 0.0) AS FLOAT) AS HorasUtilizadasPlantaOrcado  
        , CAST(ISNULL(100.0 * AlimentacaoPlantaOrcado / [@tblPeriod].HorasCalendario / @MoagemNominalProductionRate, 0.0) AS FLOAT) AS OeePlantaOrcado
        
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeIPCOrcado / 100.0), 0.0) AS FLOAT)  AS HorasDisponiveisIpcOrcado
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeIPCOrcado / 100.0) * (UtilizacaoIPCOrcado / 100.0), 0.0) AS FLOAT) AS HorasUtilizadasIpcOrcado
        , CAST(ISNULL(DisponibilidadeIPCOrcado, 0.0) AS FLOAT) AS DisponibilidadeIpcOrcado
        , CAST(ISNULL(UtilizacaoIPCOrcado, 0.0) AS FLOAT) AS UtilizacaoIpcOrcado
        , CAST(ISNULL(ProdutividadeIPCOrcado, 0.0) AS FLOAT) AS ProdutividadeIpcOrcado
        , CAST(ISNULL(100.0 * AlimentacaoIPCOrcado / [@tblPeriod].HorasCalendario / @IpcNominalProductionRate, 0.0) AS FLOAT) AS OeeIpcOrcado
        
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeMMDOrcado / 100.0), 0.0) AS FLOAT)  AS HorasDisponiveisMmdOrcado
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeMMDOrcado / 100.0) * (UtilizacaoMMDOrcado / 100.0), 0.0) AS FLOAT) AS HorasUtilizadasMmdOrcado
        , CAST(ISNULL(DisponibilidadeMMDOrcado, 0.0) AS FLOAT) AS DisponibilidadeMmdOrcado
        , CAST(ISNULL(UtilizacaoMMDOrcado, 0.0) AS FLOAT) AS UtilizacaoMmdOrcado
        , CAST(ISNULL(ProdutividadeMMDOrcado, 0.0) AS FLOAT) AS ProdutividadeMmdOrcado
        , CAST(ISNULL(100.0 * AlimentacaoMMDOrcado / [@tblPeriod].HorasCalendario / @MmdNominalProductionRate, 0.0) AS FLOAT) AS OeeMmdOrcado
        
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeC160Orcado / 100.0), 0.0) AS FLOAT) AS HorasDisponiveisMandibulasOrcado
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeC160Orcado / 100.0) * (UtilizacaoC160Orcado / 100.0), 0.0) AS FLOAT) AS HorasUtilizadasMandibulasOrcado
        , CAST(ISNULL(DisponibilidadeC160Orcado, 0.0) AS FLOAT) AS DisponibilidadeMandibulasOrcado
        , CAST(ISNULL(UtilizacaoC160Orcado, 0.0) AS FLOAT) AS UtilizacaoMandibulasOrcado
        , CAST(ISNULL(ProdutividadeC160Orcado, 0.0) AS FLOAT) AS ProdutividadeMandibulasOrcado
        , CAST(ISNULL(100.0 * AlimentacaoC160Orcado / [@tblPeriod].HorasCalendario / @MandibulasNominalProductionRate, 0.0) AS FLOAT) AS OeeMandibulasOrcado
        
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeMMDOrcado / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160Orcado / 100.0), 0.0) AS FLOAT) AS HorasDisponiveisBritagensOrcado
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeMMDOrcado / 100.0) * (UtilizacaoMMDOrcado / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160Orcado / 100.0) * (UtilizacaoC160Orcado / 100.0), 0.0) AS FLOAT) AS HorasUtilizadasBritagensOrcado
        , CAST(ISNULL(100.0 * ([@tblPeriod].HorasCalendario * (DisponibilidadeMMDOrcado / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160Orcado / 100.0)) / 48.0, 0.0) AS FLOAT) AS DisponibilidadeBritagensOrcado
        , CAST(ISNULL(100.0 * ([@tblPeriod].HorasCalendario * (DisponibilidadeMMDOrcado / 100.0) * (UtilizacaoMMDOrcado / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160Orcado / 100.0) * (UtilizacaoC160Orcado / 100.0)) / NULLIF([@tblPeriod].HorasCalendario * (DisponibilidadeMMDOrcado / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160Orcado / 100.0), 0.0), 0.0) AS FLOAT) AS UtilizacaoBritagensOrcado
        , CAST(ISNULL((AlimentacaoMMDOrcado + AlimentacaoC160Orcado) / NULLIF([@tblPeriod].HorasCalendario * (DisponibilidadeMMDOrcado / 100.0) * (UtilizacaoMMDOrcado / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160Orcado / 100.0) * (UtilizacaoC160Orcado / 100.0), 0.0), 0.0) AS FLOAT) AS ProdutividadeBritagensOrcado
        , CAST(ISNULL(100.0 * (AlimentacaoMMDOrcado + AlimentacaoC160Orcado) / [@tblPeriod].HorasCalendario / (@MmdNominalProductionRate + @MandibulasNominalProductionRate), 0.0) AS FLOAT) AS OeeBritagensOrcado
        --Curto Prazo
        , CAST(ISNULL(AlimentacaoIPCCurtoPrazo, 0.0) AS FLOAT) AS AlimentacaoIpcCurtoPrazo
        , CAST(ISNULL(AlimentacaoMMDCurtoPrazo, 0.0) AS FLOAT) AS AlimentacaoMmdCurtoPrazo
        , CAST(ISNULL(AlimentacaoC160CurtoPrazo, 0.0) AS FLOAT) AS AlimentacaoMandibulasCurtoPrazo
        , CAST((ISNULL(AlimentacaoMMDCurtoPrazo, 0.0) + ISNULL(AlimentacaoC160CurtoPrazo, 0.0)) AS FLOAT) AS AlimentacaoBritagensCurtoPrazo 
        , CAST(ISNULL(AlimentacaoPlantaCurtoPrazo, 0.0) AS FLOAT) AS AlimentacaoPlantaCurtoPrazo
        , CAST(ISNULL(TeorAlimentacaoCobreCurtoPrazo, 0.0) AS FLOAT) AS TeorAlimentacaoCobreCurtoPrazo
        , CAST(ISNULL(TeorAlimentacaoOuroCurtoPrazo, 0.0) AS FLOAT) AS TeorAlimentacaoOuroCurtoPrazo
        , CAST(ISNULL(TeorConcentradoCobreCurtoPrazo, 0.0) AS FLOAT) AS TeorConcentradoCobreCurtoPrazo
        , CAST(ISNULL(TeorConcentradoOuroCurtoPrazo, 0.0) AS FLOAT) AS TeorConcentradoOuroCurtoPrazo
        , CAST(ISNULL(100.0 * (TeorAlimentacaoCobreCurtoPrazo / 100.0) * (TeorConcentradoCobreCurtoPrazo / 100.0) * ((RecuperacaoCobreCurtoPrazo / 100.0) - 1.0) / NULLIF(((RecuperacaoCobreCurtoPrazo / 100.0) * (TeorAlimentacaoCobreCurtoPrazo / 100.0) - (TeorConcentradoCobreCurtoPrazo / 100.0)), 0.0), 0.0) AS FLOAT) AS TeorRejeitoCobreCurtoPrazo
        , CAST(ISNULL((TeorAlimentacaoOuroCurtoPrazo) * (TeorConcentradoOuroCurtoPrazo) * ((RecuperacaoOuroCurtoPrazo / 100.0) - 1.0) / NULLIF(((RecuperacaoOuroCurtoPrazo / 100.0) * (TeorAlimentacaoOuroCurtoPrazo) - (TeorConcentradoOuroCurtoPrazo)), 0.0), 0.0) AS FLOAT) AS TeorRejeitoOuroCurtoPrazo
        , CAST(ISNULL(RecuperacaoCobreCurtoPrazo, 0.0) AS FLOAT)  AS RecuperacaoCobreCurtoPrazo
        , CAST(ISNULL(RecuperacaoOuroCurtoPrazo, 0.0) AS FLOAT)  AS RecuperacaoOuroCurtoPrazo
        , CAST(ISNULL(CobreContidoCurtoPrazo, 0.0) AS FLOAT)  AS CobreContidoCurtoPrazo
        , CAST(ISNULL(OuroContidoCurtoPrazo, 0.0) AS FLOAT) AS OuroContidoCurtoPrazo
        , CAST(ISNULL(MassaConcentradoCurtoPrazo, 0.0) AS FLOAT) AS MassaConcentradoCurtoPrazo
        , CAST(ISNULL(ProducaoPrataOzCurtoPrazo, 0.0) AS FLOAT) AS ProducaoPrataOzCurtoPrazo
        , CAST(ISNULL(ProducaoOuroOzCurtoPrazo, 0.0) AS FLOAT) AS ProducaoOuroOzCurtoPrazo
        , CAST(ISNULL(ProducaoOuroGEOCurtoPrazo, 0.0) AS FLOAT) AS ProducaoOuroGEOCurtoPrazo
        , CAST(ISNULL(ProducaoCobreKLBCurtoPrazo, 0.0) AS FLOAT) AS ProducaoCobreKLBCurtoPrazo
        , CAST(ISNULL(ProducaoOuroKgCurtoPrazo, 0.0) AS FLOAT) AS ProducaoOuroKgCurtoPrazo
        , CAST(ISNULL(ProducaoCobreTonCurtoPrazo, 0.0) AS FLOAT) AS ProducaoCobreTonCurtoPrazo
        , CAST(ISNULL(DisponibilidadePlantaCurtoPrazo, 0.0) AS FLOAT) AS DisponibilidadePlantaCurtoPrazo
        , CAST(ISNULL(UtilizacaoPlantaCurtoPrazo, 0.0) AS FLOAT) AS UtilizacaoPlantaCurtoPrazo
        , CAST(ISNULL(ProdutividadePlantaCurtoPrazo, 0.0) AS FLOAT) AS ProdutividadePlantaCurtoPrazo
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (1.0 - DisponibilidadePlantaCurtoPrazo / 100.0) * (ISNULL(ProporcManutProgramadaCurtoPrazo, 100.0) / 100.0), 0.0) AS FLOAT)  AS HorasParadasProgramadasCurtoPrazo 
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (1.0 - DisponibilidadePlantaCurtoPrazo / 100.0) * (ISNULL(ProporcManutCorretivaCurtoPrazo, 0.0) / 100.0), 0.0) AS FLOAT)  AS HorasParadasManutencaoCurtoPrazo 
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (1.0 - DisponibilidadePlantaCurtoPrazo / 100.0) * (ISNULL(ProporcManutCorretivaCurtoPrazo, 0.0) / 100.0) * (ISNULL(ProporcManutExternoCurtoPrazo, 0.0) / 100.0), 0.0) AS FLOAT)  AS HorasParadasExternoCurtoPrazo 
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadePlantaCurtoPrazo / 100.0) * (1.0 - UtilizacaoPlantaCurtoPrazo / 100.0), 0.0) AS FLOAT) AS HorasParadasOperacaoCurtoPrazo 
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadePlantaCurtoPrazo / 100.0), 0.0) AS FLOAT)  AS HorasDisponiveisPlantaCurtoPrazo 
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadePlantaCurtoPrazo / 100.0) * (UtilizacaoPlantaCurtoPrazo / 100.0), 0.0) AS FLOAT) AS HorasUtilizadasPlantaCurtoPrazo  
        , CAST(ISNULL(100.0 * AlimentacaoPlantaCurtoPrazo / [@tblPeriod].HorasCalendario / @MoagemNominalProductionRate, 0.0) AS FLOAT) AS OeePlantaCurtoPrazo
        
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeIPCCurtoPrazo / 100.0), 0.0) AS FLOAT)  AS HorasDisponiveisIpcCurtoPrazo
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeIPCCurtoPrazo / 100.0) * (UtilizacaoIPCCurtoPrazo / 100.0), 0.0) AS FLOAT) AS HorasUtilizadasIpcCurtoPrazo
        , CAST(ISNULL(DisponibilidadeIPCCurtoPrazo, 0.0) AS FLOAT) AS DisponibilidadeIpcCurtoPrazo
        , CAST(ISNULL(UtilizacaoIPCCurtoPrazo, 0.0) AS FLOAT) AS UtilizacaoIpcCurtoPrazo
        , CAST(ISNULL(ProdutividadeIPCCurtoPrazo, 0.0) AS FLOAT) AS ProdutividadeIpcCurtoPrazo
        , CAST(ISNULL(100.0 * AlimentacaoIPCCurtoPrazo / [@tblPeriod].HorasCalendario / @IpcNominalProductionRate, 0.0) AS FLOAT) AS OeeIpcCurtoPrazo
        
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtoPrazo / 100.0), 0.0) AS FLOAT)  AS HorasDisponiveisMmdCurtoPrazo
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtoPrazo / 100.0) * (UtilizacaoMMDCurtoPrazo / 100.0), 0.0) AS FLOAT) AS HorasUtilizadasMmdCurtoPrazo
        , CAST(ISNULL(DisponibilidadeMMDCurtoPrazo, 0.0) AS FLOAT) AS DisponibilidadeMmdCurtoPrazo
        , CAST(ISNULL(UtilizacaoMMDCurtoPrazo, 0.0) AS FLOAT) AS UtilizacaoMmdCurtoPrazo
        , CAST(ISNULL(ProdutividadeMMDCurtoPrazo, 0.0) AS FLOAT) AS ProdutividadeMmdCurtoPrazo
        , CAST(ISNULL(100.0 * AlimentacaoMMDCurtoPrazo / [@tblPeriod].HorasCalendario / @MmdNominalProductionRate, 0.0) AS FLOAT) AS OeeMmdCurtoPrazo
        
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtoPrazo / 100.0), 0.0) AS FLOAT) AS HorasDisponiveisMandibulasCurtoPrazo
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtoPrazo / 100.0) * (UtilizacaoC160CurtoPrazo / 100.0), 0.0) AS FLOAT) AS HorasUtilizadasMandibulasCurtoPrazo
        , CAST(ISNULL(DisponibilidadeC160CurtoPrazo, 0.0) AS FLOAT) AS DisponibilidadeMandibulasCurtoPrazo
        , CAST(ISNULL(UtilizacaoC160CurtoPrazo, 0.0) AS FLOAT) AS UtilizacaoMandibulasCurtoPrazo
        , CAST(ISNULL(ProdutividadeC160CurtoPrazo, 0.0) AS FLOAT) AS ProdutividadeMandibulasCurtoPrazo
        , CAST(ISNULL(100.0 * AlimentacaoC160CurtoPrazo / [@tblPeriod].HorasCalendario / @MandibulasNominalProductionRate, 0.0) AS FLOAT) AS OeeMandibulasCurtoPrazo
        
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtoPrazo / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtoPrazo / 100.0), 0.0) AS FLOAT) AS HorasDisponiveisBritagensCurtoPrazo
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtoPrazo / 100.0) * (UtilizacaoMMDCurtoPrazo / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtoPrazo / 100.0) * (UtilizacaoC160CurtoPrazo / 100.0), 0.0) AS FLOAT) AS HorasUtilizadasBritagensCurtoPrazo
        , CAST(ISNULL(100.0 * ([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtoPrazo / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtoPrazo / 100.0)) / 48.0, 0.0) AS FLOAT) AS DisponibilidadeBritagensCurtoPrazo
        , CAST(ISNULL(100.0 * ([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtoPrazo / 100.0) * (UtilizacaoMMDCurtoPrazo / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtoPrazo / 100.0) * (UtilizacaoC160CurtoPrazo / 100.0)) / NULLIF([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtoPrazo / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtoPrazo / 100.0), 0.0), 0.0) AS FLOAT) AS UtilizacaoBritagensCurtoPrazo
        , CAST(ISNULL((AlimentacaoMMDCurtoPrazo + AlimentacaoC160CurtoPrazo) / NULLIF([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtoPrazo / 100.0) * (UtilizacaoMMDCurtoPrazo / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtoPrazo / 100.0) * (UtilizacaoC160CurtoPrazo / 100.0), 0.0), 0.0) AS FLOAT) AS ProdutividadeBritagensCurtoPrazo
        , CAST(ISNULL(100.0 * (AlimentacaoMMDCurtoPrazo + AlimentacaoC160CurtoPrazo) / [@tblPeriod].HorasCalendario / (@MmdNominalProductionRate + @MandibulasNominalProductionRate), 0.0) AS FLOAT) AS OeeBritagensCurtoPrazo
        --Curtissimo Prazo
        , CAST(ISNULL(AlimentacaoIPCCurtissimoPrazo, 0.0) AS FLOAT) AS AlimentacaoIpcCurtissimoPrazo
        , CAST(ISNULL(AlimentacaoMMDCurtissimoPrazo, 0.0) AS FLOAT) AS AlimentacaoMmdCurtissimoPrazo
        , CAST(ISNULL(AlimentacaoC160CurtissimoPrazo, 0.0) AS FLOAT) AS AlimentacaoMandibulasCurtissimoPrazo
        , CAST((ISNULL(AlimentacaoMMDCurtissimoPrazo, 0.0) + ISNULL(AlimentacaoC160CurtissimoPrazo, 0.0)) AS FLOAT) AS AlimentacaoBritagensCurtissimoPrazo 
        , CAST(ISNULL(AlimentacaoPlantaCurtissimoPrazo, 0.0) AS FLOAT) AS AlimentacaoPlantaCurtissimoPrazo
        , CAST(ISNULL(TeorAlimentacaoCobreCurtissimoPrazo, 0.0) AS FLOAT) AS TeorAlimentacaoCobreCurtissimoPrazo
        , CAST(ISNULL(TeorAlimentacaoOuroCurtissimoPrazo, 0.0) AS FLOAT) AS TeorAlimentacaoOuroCurtissimoPrazo
        , CAST(ISNULL(TeorConcentradoCobreCurtissimoPrazo, 0.0) AS FLOAT) AS TeorConcentradoCobreCurtissimoPrazo
        , CAST(ISNULL(TeorConcentradoOuroCurtissimoPrazo, 0.0) AS FLOAT) AS TeorConcentradoOuroCurtissimoPrazo
        , CAST(ISNULL(100.0 * (TeorAlimentacaoCobreCurtissimoPrazo / 100.0) * (TeorConcentradoCobreCurtissimoPrazo / 100.0) * ((RecuperacaoCobreCurtissimoPrazo / 100.0) - 1.0) / NULLIF(((RecuperacaoCobreCurtissimoPrazo / 100.0) * (TeorAlimentacaoCobreCurtissimoPrazo / 100.0) - (TeorConcentradoCobreCurtissimoPrazo / 100.0)), 0.0), 0.0) AS FLOAT) AS TeorRejeitoCobreCurtissimoPrazo
        , CAST(ISNULL((TeorAlimentacaoOuroCurtissimoPrazo) * (TeorConcentradoOuroCurtissimoPrazo) * ((RecuperacaoOuroCurtissimoPrazo / 100.0) - 1.0) / NULLIF(((RecuperacaoOuroCurtissimoPrazo / 100.0) * (TeorAlimentacaoOuroCurtissimoPrazo) - (TeorConcentradoOuroCurtissimoPrazo)), 0.0), 0.0) AS FLOAT) AS TeorRejeitoOuroCurtissimoPrazo
        , CAST(ISNULL(RecuperacaoCobreCurtissimoPrazo, 0.0) AS FLOAT)  AS RecuperacaoCobreCurtissimoPrazo
        , CAST(ISNULL(RecuperacaoOuroCurtissimoPrazo, 0.0) AS FLOAT)  AS RecuperacaoOuroCurtissimoPrazo
        , CAST(ISNULL(CobreContidoCurtissimoPrazo, 0.0) AS FLOAT)  AS CobreContidoCurtissimoPrazo
        , CAST(ISNULL(OuroContidoCurtissimoPrazo, 0.0) AS FLOAT) AS OuroContidoCurtissimoPrazo
        , CAST(ISNULL(MassaConcentradoCurtissimoPrazo, 0.0) AS FLOAT) AS MassaConcentradoCurtissimoPrazo
        , CAST(ISNULL(ProducaoPrataOzCurtissimoPrazo, 0.0) AS FLOAT) AS ProducaoPrataOzCurtissimoPrazo
        , CAST(ISNULL(ProducaoOuroOzCurtissimoPrazo, 0.0) AS FLOAT) AS ProducaoOuroOzCurtissimoPrazo
        , CAST(ISNULL(ProducaoOuroGEOCurtissimoPrazo, 0.0) AS FLOAT) AS ProducaoOuroGEOCurtissimoPrazo
        , CAST(ISNULL(ProducaoCobreKLBCurtissimoPrazo, 0.0) AS FLOAT) AS ProducaoCobreKLBCurtissimoPrazo
        , CAST(ISNULL(ProducaoOuroKgCurtissimoPrazo, 0.0) AS FLOAT) AS ProducaoOuroKgCurtissimoPrazo
        , CAST(ISNULL(ProducaoCobreTonCurtissimoPrazo, 0.0) AS FLOAT) AS ProducaoCobreTonCurtissimoPrazo
        , CAST(ISNULL(DisponibilidadePlantaCurtissimoPrazo, 0.0) AS FLOAT) AS DisponibilidadePlantaCurtissimoPrazo
        , CAST(ISNULL(UtilizacaoPlantaCurtissimoPrazo, 0.0) AS FLOAT) AS UtilizacaoPlantaCurtissimoPrazo
        , CAST(ISNULL(ProdutividadePlantaCurtissimoPrazo, 0.0) AS FLOAT) AS ProdutividadePlantaCurtissimoPrazo
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (1.0 - DisponibilidadePlantaCurtissimoPrazo / 100.0) * (ISNULL(ProporcManutProgramadaCurtissimoPrazo, 100.0) / 100.0), 0.0) AS FLOAT)  AS HorasParadasProgramadasCurtissimoPrazo 
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (1.0 - DisponibilidadePlantaCurtissimoPrazo / 100.0) * (ISNULL(ProporcManutCorretivaCurtissimoPrazo, 0.0) / 100.0), 0.0) AS FLOAT)  AS HorasParadasManutencaoCurtissimoPrazo 
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (1.0 - DisponibilidadePlantaCurtissimoPrazo / 100.0) * (ISNULL(ProporcManutCorretivaCurtissimoPrazo, 0.0) / 100.0) * (ISNULL(ProporcManutExternoCurtissimoPrazo, 0.0) / 100.0), 0.0) AS FLOAT)  AS HorasParadasExternoCurtissimoPrazo  
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadePlantaCurtissimoPrazo / 100.0) * (1.0 - UtilizacaoPlantaCurtissimoPrazo / 100.0), 0.0) AS FLOAT) AS HorasParadasOperacaoCurtissimoPrazo 
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadePlantaCurtissimoPrazo / 100.0), 0.0) AS FLOAT)  AS HorasDisponiveisPlantaCurtissimoPrazo 
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadePlantaCurtissimoPrazo / 100.0) * (UtilizacaoPlantaCurtissimoPrazo / 100.0), 0.0) AS FLOAT) AS HorasUtilizadasPlantaCurtissimoPrazo  
        , CAST(ISNULL(100.0 * AlimentacaoPlantaCurtissimoPrazo / [@tblPeriod].HorasCalendario / @MoagemNominalProductionRate, 0.0) AS FLOAT) AS OeePlantaCurtissimoPrazo
        
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeIPCCurtissimoPrazo / 100.0), 0.0) AS FLOAT)  AS HorasDisponiveisIpcCurtissimoPrazo
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeIPCCurtissimoPrazo / 100.0) * (UtilizacaoIPCCurtissimoPrazo / 100.0), 0.0) AS FLOAT) AS HorasUtilizadasIpcCurtissimoPrazo
        , CAST(ISNULL(DisponibilidadeIPCCurtissimoPrazo, 0.0) AS FLOAT) AS DisponibilidadeIpcCurtissimoPrazo
        , CAST(ISNULL(UtilizacaoIPCCurtissimoPrazo, 0.0) AS FLOAT) AS UtilizacaoIpcCurtissimoPrazo
        , CAST(ISNULL(ProdutividadeIPCCurtissimoPrazo, 0.0) AS FLOAT) AS ProdutividadeIpcCurtissimoPrazo
        , CAST(ISNULL(100.0 * AlimentacaoIPCCurtissimoPrazo / [@tblPeriod].HorasCalendario / @IpcNominalProductionRate, 0.0) AS FLOAT) AS OeeIpcCurtissimoPrazo
        
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtissimoPrazo / 100.0), 0.0) AS FLOAT)  AS HorasDisponiveisMmdCurtissimoPrazo
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtissimoPrazo / 100.0) * (UtilizacaoMMDCurtissimoPrazo / 100.0), 0.0) AS FLOAT) AS HorasUtilizadasMmdCurtissimoPrazo
        , CAST(ISNULL(DisponibilidadeMMDCurtissimoPrazo, 0.0) AS FLOAT) AS DisponibilidadeMmdCurtissimoPrazo
        , CAST(ISNULL(UtilizacaoMMDCurtissimoPrazo, 0.0) AS FLOAT) AS UtilizacaoMmdCurtissimoPrazo
        , CAST(ISNULL(ProdutividadeMMDCurtissimoPrazo, 0.0) AS FLOAT) AS ProdutividadeMmdCurtissimoPrazo
        , CAST(ISNULL(100.0 * AlimentacaoMMDCurtissimoPrazo / [@tblPeriod].HorasCalendario / @MmdNominalProductionRate, 0.0) AS FLOAT) AS OeeMmdCurtissimoPrazo
        
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtissimoPrazo / 100.0), 0.0) AS FLOAT) AS HorasDisponiveisMandibulasCurtissimoPrazo
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtissimoPrazo / 100.0) * (UtilizacaoC160CurtissimoPrazo / 100.0), 0.0) AS FLOAT) AS HorasUtilizadasMandibulasCurtissimoPrazo
        , CAST(ISNULL(DisponibilidadeC160CurtissimoPrazo, 0.0) AS FLOAT) AS DisponibilidadeMandibulasCurtissimoPrazo
        , CAST(ISNULL(UtilizacaoC160CurtissimoPrazo, 0.0) AS FLOAT) AS UtilizacaoMandibulasCurtissimoPrazo
        , CAST(ISNULL(ProdutividadeC160CurtissimoPrazo, 0.0) AS FLOAT) AS ProdutividadeMandibulasCurtissimoPrazo
        , CAST(ISNULL(100.0 * AlimentacaoC160CurtissimoPrazo / [@tblPeriod].HorasCalendario / @MandibulasNominalProductionRate, 0.0) AS FLOAT) AS OeeMandibulasCurtissimoPrazo
        
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtissimoPrazo / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtissimoPrazo / 100.0), 0.0) AS FLOAT) AS HorasDisponiveisBritagensCurtissimoPrazo
        , CAST(ISNULL([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtissimoPrazo / 100.0) * (UtilizacaoMMDCurtissimoPrazo / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtissimoPrazo / 100.0) * (UtilizacaoC160CurtissimoPrazo / 100.0), 0.0) AS FLOAT) AS HorasUtilizadasBritagensCurtissimoPrazo
        , CAST(ISNULL(100.0 * ([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtissimoPrazo / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtissimoPrazo / 100.0)) / 48.0, 0.0) AS FLOAT) AS DisponibilidadeBritagensCurtissimoPrazo
        , CAST(ISNULL(100.0 * ([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtissimoPrazo / 100.0) * (UtilizacaoMMDCurtissimoPrazo / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtissimoPrazo / 100.0) * (UtilizacaoC160CurtissimoPrazo / 100.0)) / NULLIF([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtissimoPrazo / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtissimoPrazo / 100.0), 0.0), 0.0) AS FLOAT) AS UtilizacaoBritagensCurtissimoPrazo
        , CAST(ISNULL((AlimentacaoMMDCurtissimoPrazo + AlimentacaoC160CurtissimoPrazo) / NULLIF([@tblPeriod].HorasCalendario * (DisponibilidadeMMDCurtissimoPrazo / 100.0) * (UtilizacaoMMDCurtissimoPrazo / 100.0) + [@tblPeriod].HorasCalendario * (DisponibilidadeC160CurtissimoPrazo / 100.0) * (UtilizacaoC160CurtissimoPrazo / 100.0), 0.0), 0.0) AS FLOAT) AS ProdutividadeBritagensCurtissimoPrazo
        , CAST(ISNULL(100.0 * (AlimentacaoMMDCurtissimoPrazo + AlimentacaoC160CurtissimoPrazo) / [@tblPeriod].HorasCalendario / (@MmdNominalProductionRate + @MandibulasNominalProductionRate), 0.0) AS FLOAT) AS OeeBritagensCurtissimoPrazo
        
        -- Teores e Recuperação Acumulados até a data
        , CAST(TeorAlimentacaoCobreRealAcumulado AS FLOAT) AS TeorAlimentacaoCobreRealAcumulado
        , CAST(TeorAlimentacaoOuroRealAcumulado AS FLOAT) AS TeorAlimentacaoOuroRealAcumulado   
        , CAST(TeorConcentradoCobreRealAcumulado AS FLOAT) AS TeorConcentradoCobreRealAcumulado
        , CAST(TeorConcentradoOuroRealAcumulado AS FLOAT) AS TeorConcentradoOuroRealAcumulado
        , CAST(TeorRejeitoCobreRealAcumulado AS FLOAT) AS TeorRejeitoCobreRealAcumulado
        , CAST(TeorRejeitoOuroRealAcumulado AS FLOAT) AS TeorRejeitoOuroRealAcumulado 
        , CAST(RecuperacaoCobreRealAcumulado AS FLOAT) AS RecuperacaoCobreRealAcumulado 
        , CAST(RecuperacaoOuroRealAcumulado AS FLOAT) AS RecuperacaoOuroRealAcumulado 
        
        , CAST(TeorAlimentacaoCobreOrcadoAcumulado AS FLOAT) AS TeorAlimentacaoCobreOrcadoAcumulado
        , CAST(TeorAlimentacaoOuroOrcadoAcumulado AS FLOAT) AS TeorAlimentacaoOuroOrcadoAcumulado   
        , CAST(TeorConcentradoCobreOrcadoAcumulado AS FLOAT) AS TeorConcentradoCobreOrcadoAcumulado
        , CAST(TeorConcentradoOuroOrcadoAcumulado AS FLOAT) AS TeorConcentradoOuroOrcadoAcumulado
        , CAST(TeorRejeitoCobreOrcadoAcumulado AS FLOAT) AS TeorRejeitoCobreOrcadoAcumulado
        , CAST(TeorRejeitoOuroOrcadoAcumulado AS FLOAT) AS TeorRejeitoOuroOrcadoAcumulado 
        , CAST(RecuperacaoCobreOrcadoAcumulado AS FLOAT) AS RecuperacaoCobreOrcadoAcumulado 
        , CAST(RecuperacaoOuroOrcadoAcumulado AS FLOAT) AS RecuperacaoOuroOrcadoAcumulado
        
        , CAST(TeorAlimentacaoCobreProjecao AS FLOAT) AS TeorAlimentacaoCobreProjecao
        , CAST(TeorAlimentacaoOuroProjecao AS FLOAT) AS TeorAlimentacaoOuroProjecao   
        , CAST(TeorConcentradoCobreProjecao AS FLOAT) AS TeorConcentradoCobreProjecao
        , CAST(TeorConcentradoOuroProjecao AS FLOAT) AS TeorConcentradoOuroProjecao
        , CAST(TeorRejeitoCobreProjecao AS FLOAT) AS TeorRejeitoCobreProjecao
        , CAST(TeorRejeitoOuroProjecao AS FLOAT) AS TeorRejeitoOuroProjecao 
        , CAST(RecuperacaoCobreProjecao AS FLOAT) AS RecuperacaoCobreProjecao 
        , CAST(RecuperacaoOuroProjecao AS FLOAT) AS RecuperacaoOuroProjecao
        
        FROM @tblPeriod 
        LEFT JOIN (SELECT [@tblPeriod].PeriodIndex 
                        , AVG(ISNULL([TBL_GPROD_OBJ_32].[CDL_NUMBER_00030], 1.0)) * SUM(ISNULL(NULLIF([TBL_GPROD_OBJ_0].CDL_NUMBER_00018, -999), 0.0)) AS AlimentacaoIPCReal
                        , AVG(ISNULL([TBL_GPROD_OBJ_32].[CDL_NUMBER_00030], 1.0)) * SUM(ISNULL(NULLIF([TBL_GPROD_OBJ_0].CDL_NUMBER_00012, -999), 0.0)) AS AlimentacaoMMDReal
                        , AVG(ISNULL([TBL_GPROD_OBJ_32].[CDL_NUMBER_00030], 1.0)) * SUM(ISNULL(NULLIF([TBL_GPROD_OBJ_0].CDL_NUMBER_00015, -999), 0.0)) AS AlimentacaoC160Real
                        , AVG(ISNULL([TBL_GPROD_OBJ_32].[CDL_NUMBER_00030], 1.0)) * SUM(ISNULL(NULLIF([TBL_GPROD_OBJ_0].CDL_NUMBER_00012, -999), 0.0) + ISNULL(NULLIF([TBL_GPROD_OBJ_0].CDL_NUMBER_00015, -999), 0.0)) AS AlimentacaoBritagensReal
                    FROM @tblPeriod 
                    INNER JOIN [dbo].[TBL_GPROD_OBJ_0] ON ([TBL_GPROD_OBJ_0].CDL_DATETIME_00001 >= [@tblPeriod].StartPeriod AND [TBL_GPROD_OBJ_0].CDL_DATETIME_00001 < [@tblPeriod].EndPeriod)
                    INNER JOIN [dbo].[TBL_GPROD_OBJ_32] ON ([TBL_GPROD_OBJ_32].[CDL_DATETIME_00001] = [@tblPeriod].PeriodIndex)
                    WHERE [TBL_GPROD_OBJ_0].CDL_DATETIME_00001 >= @StartDate AND [TBL_GPROD_OBJ_0].CDL_DATETIME_00001 < @EndDate
                        AND [TBL_GPROD_OBJ_32].CDL_DATETIME_00001 >= @StartDateIndex AND [TBL_GPROD_OBJ_32].CDL_DATETIME_00001 < @EndDateIndex
                    GROUP BY [@tblPeriod].PeriodIndex
                ) BRITAGENS  ON ([@tblPeriod].PeriodIndex = BRITAGENS.PeriodIndex)
        LEFT JOIN (SELECT PeriodIndex
                    , AlimentacaoPlantaReal
                    , ConcentradoReal
                    , P80FlotacaoReal
                    , TeorAlimentacaoCobreReal
                    , TeorAlimentacaoOuroReal
                    , TeorAlimentacaoEnxofreReal
                    , TeorConcentradoCobreReal
                    , TeorConcentradoOuroReal
                    , TeorRejeitoCobreReal
                    , TeorRejeitoOuroReal
                    , ((TeorAlimentacaoCobreReal - TeorRejeitoCobreReal) / NULLIF((TeorConcentradoCobreReal - TeorRejeitoCobreReal), 0.0)) * (TeorConcentradoCobreReal / NULLIF(TeorAlimentacaoCobreReal, 0.0)) AS RecuperacaoCobreReal 
                    , ((TeorAlimentacaoOuroReal - TeorRejeitoOuroReal) / NULLIF((TeorConcentradoOuroReal - TeorRejeitoOuroReal), 0.0)) * (TeorConcentradoOuroReal / NULLIF(TeorAlimentacaoOuroReal, 0.0)) AS RecuperacaoOuroReal 
                    FROM
                    (SELECT [@tblPeriod].PeriodIndex
                        , SUM([@tblTeores].MoagemToneladasSecas) AS AlimentacaoPlantaReal
                        , SUM([@tblTeores].Concentrado) AS ConcentradoReal
                        , SUM(ISNULL([@tblTeores].P80Flotacao, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].P80Flotacao, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS P80FlotacaoReal 
                        , SUM(ISNULL([@tblTeores].TeorAlimentacaoCobre, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorAlimentacaoCobre, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS TeorAlimentacaoCobreReal 
                        , SUM(ISNULL([@tblTeores].TeorAlimentacaoOuro, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorAlimentacaoOuro, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS TeorAlimentacaoOuroReal 
                        , SUM(ISNULL([@tblTeores].TeorAlimentacaoEnxofre, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorAlimentacaoEnxofre, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS TeorAlimentacaoEnxofreReal 
                        --, SUM(ISNULL([@tblTeores].TeorCFColunaCobre, 0.0) * [@tblTeores].Concentrado) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorCFColunaCobre, 0.0) > 0.0 THEN [@tblTeores].Concentrado ELSE 0.0 END), 0.0) AS TeorConcentradoCobreReal 
                        --, SUM(ISNULL([@tblTeores].TeorCFColunaOuro, 0.0) * [@tblTeores].Concentrado) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorCFColunaOuro, 0.0) > 0.0 THEN [@tblTeores].Concentrado ELSE 0.0 END), 0.0) AS TeorConcentradoOuroReal 
                        , SUM(ISNULL([@tblTeores].TeorCFColunaCobre, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorCFColunaCobre, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS TeorConcentradoCobreReal 
                        , SUM(ISNULL([@tblTeores].TeorCFColunaOuro, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorCFColunaOuro, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS TeorConcentradoOuroReal 
                        , SUM(ISNULL([@tblTeores].TeorRejeitoCobre, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorRejeitoCobre, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS TeorRejeitoCobreReal 
                        , SUM(ISNULL([@tblTeores].TeorRejeitoOuro, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorRejeitoOuro, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS TeorRejeitoOuroReal 
                    FROM @tblPeriod
                    INNER JOIN @tblTeores ON ([@tblTeores].PeriodIndex >= [@tblPeriod].StartPeriod AND [@tblTeores].PeriodIndex < [@tblPeriod].EndPeriod)
                    GROUP BY  [@tblPeriod].PeriodIndex) AUX
                ) PRODUCAO ON ([@tblPeriod].PeriodIndex = PRODUCAO.PeriodIndex)
        LEFT JOIN (SELECT [TBL_GPROD_OBJ_6].CDL_DATETIME_00001 AS PeriodIndex
                        , ISNULL(NULLIF((ISNULL(NULLIF([TBL_GPROD_OBJ_6].[CDL_NUMBER_00001], -999), 0.0) *  ISNULL(NULLIF([TBL_GPROD_OBJ_6].[CDL_NUMBER_00004], -999), 0.0) / 31.1034768), 0.0), 0.0) AS ProducaoPrataOzReal
                    FROM [dbo].[TBL_GPROD_OBJ_6] 
                    WHERE [TBL_GPROD_OBJ_6].CDL_DATETIME_00001 >= @StartDateIndex AND [TBL_GPROD_OBJ_6].CDL_DATETIME_00001 < @EndDateIndex
                ) EXPEDICAO ON ([@tblPeriod].PeriodIndex = EXPEDICAO.PeriodIndex)
        LEFT JOIN (SELECT [@tblKPIsDowntimeMoagem].PeriodIndex
                        
                        , SUM(CASE WHEN [@tblKPIsDowntimeMoagem].KPIType = '1_TimeClassDuration' AND [@tblKPIsDowntimeMoagem].KPIOrder = '1.1' THEN [@tblKPIsDowntimeMoagem].KPIValue ELSE 0.0 END) As HorasDisponiveisPlantaReal
                        , SUM(CASE WHEN [@tblKPIsDowntimeMoagem].KPIType = '1_TimeClassDuration' AND [@tblKPIsDowntimeMoagem].KPIOrder = '1.1.1' THEN [@tblKPIsDowntimeMoagem].KPIValue ELSE 0.0 END) AS HorasUtilizadasPlantaReal
                        , AVG(CASE WHEN [@tblKPIsDowntimeMoagem].KPIType = '3_KPI' AND [@tblKPIsDowntimeMoagem].KPIOrder = '9999.1' AND [@tblKPIsDowntimeMoagem].KPIDescription = 'Disponibilidade (%)' THEN [@tblKPIsDowntimeMoagem].KPIValue ELSE NULL END) AS DisponibilidadePlantaReal
                        , AVG(CASE WHEN [@tblKPIsDowntimeMoagem].KPIType = '3_KPI' AND [@tblKPIsDowntimeMoagem].KPIOrder = '9999.2' AND [@tblKPIsDowntimeMoagem].KPIDescription = 'Utilização (%)' THEN [@tblKPIsDowntimeMoagem].KPIValue ELSE NULL END) AS UtilizacaoPlantaReal
                        --, AVG(CASE WHEN [@tblKPIsDowntimeMoagem].KPIType = '3_KPI' AND [@tblKPIsDowntimeMoagem].KPIOrder = '9999.5' AND [@tblKPIsDowntimeMoagem].KPIDescription = 'Produtividade (t/h)' THEN dbo.custom_fn_CheckInvalidValue([@tblKPIsDowntimeMoagem].KPIValue) ELSE NULL END) AS ProdutividadePlantaReal
                        , SUM(CASE WHEN [@tblKPIsDowntimeMoagem].KPIType = '1_TimeClassDuration' AND [@tblKPIsDowntimeMoagem].KPIOrder IN ('1.1.2', '1.1.3') THEN [@tblKPIsDowntimeMoagem].KPIValue ELSE 0.0 END) HorasParadasOperacaoReal
                        , SUM(CASE WHEN [@tblKPIsDowntimeMoagem].KPIType = '1_TimeClassDuration' AND [@tblKPIsDowntimeMoagem].KPIOrder = '1.2.1' THEN [@tblKPIsDowntimeMoagem].KPIValue ELSE 0.0 END) AS HorasParadasProgramadasReal
                        , SUM(CASE WHEN [@tblKPIsDowntimeMoagem].KPIType = '1_TimeClassDuration' AND [@tblKPIsDowntimeMoagem].KPIOrder = '1.2.2' THEN [@tblKPIsDowntimeMoagem].KPIValue ELSE 0.0 END) AS HorasParadasManutencaoReal
                        , SUM(CASE WHEN [@tblKPIsDowntimeMoagem].KPIType = '1_TimeClassDuration' AND [@tblKPIsDowntimeMoagem].KPIOrder = '1.2.3' THEN [@tblKPIsDowntimeMoagem].KPIValue ELSE 0.0 END) AS HorasParadasExternoReal
                        
                    FROM @tblKPIsDowntimeMoagem
                    GROUP BY [@tblKPIsDowntimeMoagem].PeriodIndex
                    ) DTM_PLANTA ON ([@tblPeriod].PeriodIndex = DTM_PLANTA.PeriodIndex)
        LEFT JOIN (SELECT [@tblKPIsDowntimeIPC].PeriodIndex
                        , SUM(CASE WHEN [@tblKPIsDowntimeIPC].KPIType = '1_TimeClassDuration' AND [@tblKPIsDowntimeIPC].KPIOrder = '1.1' THEN [@tblKPIsDowntimeIPC].KPIValue ELSE 0.0 END) AS HorasDisponiveisIPCReal
                        , SUM(CASE WHEN [@tblKPIsDowntimeIPC].KPIType = '1_TimeClassDuration' AND [@tblKPIsDowntimeIPC].KPIOrder = '1.1.1' THEN [@tblKPIsDowntimeIPC].KPIValue ELSE 0.0 END) AS HorasUtilizadasIPCReal
                        , AVG(CASE WHEN [@tblKPIsDowntimeIPC].KPIType = '3_KPI' AND [@tblKPIsDowntimeIPC].KPIOrder = '9999.1' AND [@tblKPIsDowntimeIPC].KPIDescription = 'Disponibilidade (%)' THEN [@tblKPIsDowntimeIPC].KPIValue ELSE NULL END) AS DisponibilidadeIPCReal
                        , AVG(CASE WHEN [@tblKPIsDowntimeIPC].KPIType = '3_KPI' AND [@tblKPIsDowntimeIPC].KPIOrder = '9999.2' AND [@tblKPIsDowntimeIPC].KPIDescription = 'Utilização (%)' THEN [@tblKPIsDowntimeIPC].KPIValue ELSE NULL END) AS UtilizacaoIPCReal
                    FROM @tblKPIsDowntimeIPC
                    GROUP BY [@tblKPIsDowntimeIPC].PeriodIndex
                    ) DTM_IPC ON ([@tblPeriod].PeriodIndex = DTM_IPC.PeriodIndex)
        LEFT JOIN (SELECT [@tblKPIsDowntimeMMD].PeriodIndex
                        , SUM(CASE WHEN [@tblKPIsDowntimeMMD].KPIType = '1_TimeClassDuration' AND [@tblKPIsDowntimeMMD].KPIOrder = '1.1' THEN [@tblKPIsDowntimeMMD].KPIValue ELSE 0.0 END) AS HorasDisponiveisMMDReal
                        , SUM(CASE WHEN [@tblKPIsDowntimeMMD].KPIType = '1_TimeClassDuration' AND [@tblKPIsDowntimeMMD].KPIOrder = '1.1.1' THEN [@tblKPIsDowntimeMMD].KPIValue ELSE 0.0 END) AS HorasUtilizadasMMDReal
                        , AVG(CASE WHEN [@tblKPIsDowntimeMMD].KPIType = '3_KPI' AND [@tblKPIsDowntimeMMD].KPIOrder = '9999.1' AND [@tblKPIsDowntimeMMD].KPIDescription = 'Disponibilidade (%)' THEN [@tblKPIsDowntimeMMD].KPIValue ELSE NULL END) AS DisponibilidadeMMDReal
                        , AVG(CASE WHEN [@tblKPIsDowntimeMMD].KPIType = '3_KPI' AND [@tblKPIsDowntimeMMD].KPIOrder = '9999.2' AND [@tblKPIsDowntimeMMD].KPIDescription = 'Utilização (%)' THEN [@tblKPIsDowntimeMMD].KPIValue ELSE NULL END) AS UtilizacaoMMDReal
                    FROM @tblKPIsDowntimeMMD
                    GROUP BY [@tblKPIsDowntimeMMD].PeriodIndex
                    ) DTM_MMD ON ([@tblPeriod].PeriodIndex = DTM_MMD.PeriodIndex)
        LEFT JOIN (SELECT [@tblKPIsDowntimeC160].PeriodIndex
                        , SUM(CASE WHEN [@tblKPIsDowntimeC160].KPIType = '1_TimeClassDuration' AND [@tblKPIsDowntimeC160].KPIOrder = '1.1' THEN [@tblKPIsDowntimeC160].KPIValue ELSE 0.0 END) AS HorasDisponiveisC160Real
                        , SUM(CASE WHEN [@tblKPIsDowntimeC160].KPIType = '1_TimeClassDuration' AND [@tblKPIsDowntimeC160].KPIOrder = '1.1.1' THEN [@tblKPIsDowntimeC160].KPIValue ELSE 0.0 END) AS HorasUtilizadasC160Real
                        , AVG(CASE WHEN [@tblKPIsDowntimeC160].KPIType = '3_KPI' AND [@tblKPIsDowntimeC160].KPIOrder = '9999.1' AND [@tblKPIsDowntimeC160].KPIDescription = 'Disponibilidade (%)' THEN [@tblKPIsDowntimeC160].KPIValue ELSE NULL END) AS DisponibilidadeC160Real
                        , AVG(CASE WHEN [@tblKPIsDowntimeC160].KPIType = '3_KPI' AND [@tblKPIsDowntimeC160].KPIOrder = '9999.2' AND [@tblKPIsDowntimeC160].KPIDescription = 'Utilização (%)' THEN [@tblKPIsDowntimeC160].KPIValue ELSE NULL END) AS UtilizacaoC160Real
                    FROM @tblKPIsDowntimeC160
                    GROUP BY [@tblKPIsDowntimeC160].PeriodIndex
                    ) DTM_C160 ON ([@tblPeriod].PeriodIndex = DTM_C160.PeriodIndex)
        LEFT JOIN (SELECT [TBL_GPROD_OBJ_15].CDL_DATETIME_00001 AS PeriodIndex
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN ISNULL([TBL_GPROD_OBJ_15].[CDL_NUMBER_00009], 0.0) ELSE 0.0 END) AS AlimentacaoIPCOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN [TBL_GPROD_OBJ_15].[CDL_NUMBER_00002] ELSE NULL END) AS DisponibilidadeIPCOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN [TBL_GPROD_OBJ_15].[CDL_NUMBER_00008] ELSE NULL END) AS UtilizacaoIPCOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN [TBL_GPROD_OBJ_15].[CDL_NUMBER_00010] ELSE NULL END) AS ProdutividadeIPCOrcado
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN ISNULL([TBL_GPROD_OBJ_15].[CDL_NUMBER_00009], 0.0) ELSE 0.0 END) AS AlimentacaoIPCCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN [TBL_GPROD_OBJ_15].[CDL_NUMBER_00002] ELSE NULL END) AS DisponibilidadeIPCCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN [TBL_GPROD_OBJ_15].[CDL_NUMBER_00008] ELSE NULL END) AS UtilizacaoIPCCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN [TBL_GPROD_OBJ_15].[CDL_NUMBER_00010] ELSE NULL END) AS ProdutividadeIPCCurtoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN ISNULL([TBL_GPROD_OBJ_15].[CDL_NUMBER_00009], 0.0) ELSE 0.0 END) AS AlimentacaoIPCCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN [TBL_GPROD_OBJ_15].[CDL_NUMBER_00002] ELSE NULL END) AS DisponibilidadeIPCCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN [TBL_GPROD_OBJ_15].[CDL_NUMBER_00008] ELSE NULL END) AS UtilizacaoIPCCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN [TBL_GPROD_OBJ_15].[CDL_NUMBER_00010] ELSE NULL END) AS ProdutividadeIPCCurtissimoPrazo
                    FROM [dbo].[TBL_GPROD_OBJ_15]
                    WHERE [TBL_GPROD_OBJ_15].[CDL_STR50_00003] = 'Planejamento - Britagem IPC' AND [TBL_GPROD_OBJ_15].CDL_NUMBER_00001 = 1 AND [TBL_GPROD_OBJ_15].CDL_NUMBER_00005 = 4 AND [TBL_GPROD_OBJ_15].CDL_DATETIME_00001 >= @StartDateIndex AND [TBL_GPROD_OBJ_15].CDL_DATETIME_00001 < @EndMonth
                    GROUP BY [TBL_GPROD_OBJ_15].CDL_DATETIME_00001
                    ) PLAN_IPC ON ([@tblPeriod].PeriodIndex = PLAN_IPC.PeriodIndex)
        LEFT JOIN (SELECT [TBL_GPROD_OBJ_15].CDL_DATETIME_00001 AS PeriodIndex
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN ISNULL([TBL_GPROD_OBJ_15].[CDL_NUMBER_00009], 0.0) ELSE 0.0 END) AS AlimentacaoMMDOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00002]) ELSE NULL END) AS DisponibilidadeMMDOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00008]) ELSE NULL END) AS UtilizacaoMMDOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00010]) ELSE NULL END) AS ProdutividadeMMDOrcado
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN ISNULL([TBL_GPROD_OBJ_15].[CDL_NUMBER_00009], 0.0) ELSE 0.0 END) AS AlimentacaoMMDCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00002]) ELSE NULL END) AS DisponibilidadeMMDCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00008]) ELSE NULL END) AS UtilizacaoMMDCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00010]) ELSE NULL END) AS ProdutividadeMMDCurtoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN ISNULL([TBL_GPROD_OBJ_15].[CDL_NUMBER_00009], 0.0) ELSE 0.0 END) AS AlimentacaoMMDCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00002]) ELSE NULL END) AS DisponibilidadeMMDCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00008]) ELSE NULL END) AS UtilizacaoMMDCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00010]) ELSE NULL END) AS ProdutividadeMMDCurtissimoPrazo
                    FROM [dbo].[TBL_GPROD_OBJ_15]
                    WHERE [TBL_GPROD_OBJ_15].[CDL_STR50_00003] = 'Planejamento - Britagem MMD' AND [TBL_GPROD_OBJ_15].CDL_NUMBER_00001 = 1 AND [TBL_GPROD_OBJ_15].CDL_NUMBER_00005 = 4 AND [TBL_GPROD_OBJ_15].CDL_DATETIME_00001 >= @StartDateIndex AND [TBL_GPROD_OBJ_15].CDL_DATETIME_00001 < @EndMonth
                    GROUP BY [TBL_GPROD_OBJ_15].CDL_DATETIME_00001
                    ) PLAN_MMD ON ([@tblPeriod].PeriodIndex = PLAN_MMD.PeriodIndex)
        LEFT JOIN (SELECT [TBL_GPROD_OBJ_15].CDL_DATETIME_00001 AS PeriodIndex
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN ISNULL([TBL_GPROD_OBJ_15].[CDL_NUMBER_00009], 0.0) ELSE 0.0 END) AS AlimentacaoC160Orcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00002]) ELSE NULL END) AS DisponibilidadeC160Orcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00008]) ELSE NULL END) AS UtilizacaoC160Orcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00010]) ELSE NULL END) AS ProdutividadeC160Orcado
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN ISNULL([TBL_GPROD_OBJ_15].[CDL_NUMBER_00009], 0.0) ELSE 0.0 END) AS AlimentacaoC160CurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00002]) ELSE NULL END) AS DisponibilidadeC160CurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00008]) ELSE NULL END) AS UtilizacaoC160CurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00010]) ELSE NULL END) AS ProdutividadeC160CurtoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN ISNULL([TBL_GPROD_OBJ_15].[CDL_NUMBER_00009], 0.0) ELSE 0.0 END) AS AlimentacaoC160CurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00002]) ELSE NULL END) AS DisponibilidadeC160CurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00008]) ELSE NULL END) AS UtilizacaoC160CurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00010]) ELSE NULL END) AS ProdutividadeC160CurtissimoPrazo
                    FROM [dbo].[TBL_GPROD_OBJ_15]
                    WHERE [TBL_GPROD_OBJ_15].[CDL_STR50_00003] = 'Planejamento - Britagem Mandíbula' AND [TBL_GPROD_OBJ_15].CDL_NUMBER_00001 = 1 AND [TBL_GPROD_OBJ_15].CDL_NUMBER_00005 = 4 AND [TBL_GPROD_OBJ_15].CDL_DATETIME_00001 >= @StartDateIndex AND [TBL_GPROD_OBJ_15].CDL_DATETIME_00001 < @EndMonth
                    GROUP BY [TBL_GPROD_OBJ_15].CDL_DATETIME_00001
                    ) PLAN_C160 ON ([@tblPeriod].PeriodIndex = PLAN_C160.PeriodIndex)
        LEFT JOIN (SELECT [TBL_GPROD_OBJ_15].CDL_DATETIME_00001 AS PeriodIndex
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN ISNULL([TBL_GPROD_OBJ_15].[CDL_NUMBER_00009], 0.0) ELSE 0.0 END) AS AlimentacaoPlantaOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00002]) ELSE NULL END) AS DisponibilidadePlantaOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00008]) ELSE NULL END) AS UtilizacaoPlantaOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00010]) ELSE NULL END) AS ProdutividadePlantaOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00019]) ELSE NULL END) AS ProporcManutProgramadaOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00018]) ELSE NULL END) AS ProporcManutCorretivaOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = @planType THEN (100.0 - ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00014] + [TBL_GPROD_OBJ_15].[CDL_NUMBER_00015]) + [TBL_GPROD_OBJ_15].[CDL_NUMBER_00016] + [TBL_GPROD_OBJ_15].[CDL_NUMBER_00017]) ELSE NULL END) AS ProporcManutExternoOrcado
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN ISNULL([TBL_GPROD_OBJ_15].[CDL_NUMBER_00009], 0.0) ELSE 0.0 END) AS AlimentacaoPlantaCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00002]) ELSE NULL END) AS DisponibilidadePlantaCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00008]) ELSE NULL END) AS UtilizacaoPlantaCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00010]) ELSE NULL END) AS ProdutividadePlantaCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00019]) ELSE NULL END) AS ProporcManutProgramadaCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00018]) ELSE NULL END) AS ProporcManutCorretivaCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 3 THEN (100.0 - ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00014] + [TBL_GPROD_OBJ_15].[CDL_NUMBER_00015]) + [TBL_GPROD_OBJ_15].[CDL_NUMBER_00016] + [TBL_GPROD_OBJ_15].[CDL_NUMBER_00017]) ELSE NULL END) AS ProporcManutExternoCurtoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN ISNULL([TBL_GPROD_OBJ_15].[CDL_NUMBER_00009], 0.0) ELSE 0.0 END) AS AlimentacaoPlantaCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00002]) ELSE NULL END) AS DisponibilidadePlantaCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00008]) ELSE NULL END) AS UtilizacaoPlantaCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00010]) ELSE NULL END) AS ProdutividadePlantaCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00019]) ELSE NULL END) AS ProporcManutProgramadaCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00018]) ELSE NULL END) AS ProporcManutCorretivaCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_15].CDL_NUMBER_00006 = 4 THEN (100.0 - ([TBL_GPROD_OBJ_15].[CDL_NUMBER_00014] + [TBL_GPROD_OBJ_15].[CDL_NUMBER_00015]) + [TBL_GPROD_OBJ_15].[CDL_NUMBER_00016] + [TBL_GPROD_OBJ_15].[CDL_NUMBER_00017]) ELSE NULL END) AS ProporcManutExternoCurtissimoPrazo
                    FROM [dbo].[TBL_GPROD_OBJ_15]
                    WHERE [TBL_GPROD_OBJ_15].[CDL_STR50_00003] = 'Planejamento - Moagem' AND [TBL_GPROD_OBJ_15].CDL_NUMBER_00001 = 1 AND [TBL_GPROD_OBJ_15].CDL_NUMBER_00005 = 4 AND [TBL_GPROD_OBJ_15].CDL_DATETIME_00001 >= @StartDateIndex AND [TBL_GPROD_OBJ_15].CDL_DATETIME_00001 < @EndMonth
                    GROUP BY [TBL_GPROD_OBJ_15].CDL_DATETIME_00001
                    ) PLAN_PLANTA ON ([@tblPeriod].PeriodIndex = PLAN_PLANTA.PeriodIndex)
                    --INSERT INTO @tblPlanejamentoProducao(PeriodIndex, , , , , , , , , , , , , , , , TeorAlimentacaoCobreCurtoPrazo, CobreContidoCurtoPrazo, TeorAlimentacaoOuroCurtoPrazo, OuroContidoCurtoPrazo, RecuperacaoCobreCurtoPrazo, RecuperacaoOuroCurtoPrazo, TeorConcentradoCobreCurtoPrazo, TeorConcentradoOuroCurtoPrazo, MassaConcentradoCurtoPrazo, ProducaoPrataOzCurtoPrazo, ProducaoOuroOzCurtoPrazo, ProducaoOuroGEOCurtoPrazo, ProducaoCobreKLBCurtoPrazo, ProducaoOuroKgCurtoPrazo, ProducaoCobreTonCurtoPrazo)
        LEFT JOIN (SELECT [TBL_GPROD_OBJ_18].CDL_DATETIME_00001  AS PeriodIndex
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00007]) ELSE NULL END) AS TeorAlimentacaoCobreOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00009]) ELSE NULL END) AS CobreContidoOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00008]) ELSE NULL END) AS TeorAlimentacaoOuroOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00010]) ELSE NULL END) AS OuroContidoOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00011]) ELSE NULL END) AS RecuperacaoCobreOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00012]) ELSE NULL END) AS RecuperacaoOuroOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00013]) ELSE NULL END) AS TeorConcentradoCobreOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = @planType THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00014]) ELSE NULL END) AS TeorConcentradoOuroOrcado
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = @planType THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00015], 0.0) ELSE 0.0 END) AS MassaConcentradoOrcado
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = @planType THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00018], 0.0) ELSE 0.0 END) AS ProducaoPrataOzOrcado
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = @planType THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00019], 0.0) ELSE 0.0 END) AS ProducaoOuroOzOrcado
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = @planType THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00020], 0.0) ELSE 0.0 END) AS ProducaoOuroGEOOrcado
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = @planType THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00021], 0.0) ELSE 0.0 END) AS ProducaoCobreKLBOrcado
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = @planType THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00017], 0.0) ELSE 0.0 END) AS ProducaoOuroKgOrcado
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = @planType THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00016], 0.0) ELSE 0.0 END) AS ProducaoCobreTonOrcado
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00007]) ELSE NULL END) AS TeorAlimentacaoCobreCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00009]) ELSE NULL END) AS CobreContidoCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00008]) ELSE NULL END) AS TeorAlimentacaoOuroCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00010]) ELSE NULL END) AS OuroContidoCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00011]) ELSE NULL END) AS RecuperacaoCobreCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00012]) ELSE NULL END) AS RecuperacaoOuroCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00013]) ELSE NULL END) AS TeorConcentradoCobreCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 3 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00014]) ELSE NULL END) AS TeorConcentradoOuroCurtoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 3 THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00015], 0.0) ELSE 0.0 END) AS MassaConcentradoCurtoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 3 THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00018], 0.0) ELSE 0.0 END) AS ProducaoPrataOzCurtoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 3 THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00019], 0.0) ELSE 0.0 END) AS ProducaoOuroOzCurtoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 3 THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00020], 0.0) ELSE 0.0 END) AS ProducaoOuroGEOCurtoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 3 THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00021], 0.0) ELSE 0.0 END) AS ProducaoCobreKLBCurtoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 3 THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00017], 0.0) ELSE 0.0 END) AS ProducaoOuroKgCurtoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 3 THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00016], 0.0) ELSE 0.0 END) AS ProducaoCobreTonCurtoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00007]) ELSE NULL END) AS TeorAlimentacaoCobreCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00009]) ELSE NULL END) AS CobreContidoCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00008]) ELSE NULL END) AS TeorAlimentacaoOuroCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00010]) ELSE NULL END) AS OuroContidoCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00011]) ELSE NULL END) AS RecuperacaoCobreCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00012]) ELSE NULL END) AS RecuperacaoOuroCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00013]) ELSE NULL END) AS TeorConcentradoCobreCurtissimoPrazo
                        , AVG(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 4 THEN ([TBL_GPROD_OBJ_18].[CDL_NUMBER_00014]) ELSE NULL END) AS TeorConcentradoOuroCurtissimoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 4 THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00015], 0.0) ELSE 0.0 END) AS MassaConcentradoCurtissimoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 4 THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00018], 0.0) ELSE 0.0 END) AS ProducaoPrataOzCurtissimoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 4 THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00019], 0.0) ELSE 0.0 END) AS ProducaoOuroOzCurtissimoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 4 THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00020], 0.0) ELSE 0.0 END) AS ProducaoOuroGEOCurtissimoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 4 THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00021], 0.0) ELSE 0.0 END) AS ProducaoCobreKLBCurtissimoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 4 THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00017], 0.0) ELSE 0.0 END) AS ProducaoOuroKgCurtissimoPrazo
                        , SUM(CASE WHEN [TBL_GPROD_OBJ_18].CDL_NUMBER_00006 = 4 THEN ISNULL([TBL_GPROD_OBJ_18].[CDL_NUMBER_00016], 0.0) ELSE 0.0 END) AS ProducaoCobreTonCurtissimoPrazo

                    FROM [dbo].[TBL_GPROD_OBJ_18] 
                    WHERE [TBL_GPROD_OBJ_18].CDL_NUMBER_00001 = 1 AND [TBL_GPROD_OBJ_18].CDL_NUMBER_00005 = 4 AND [TBL_GPROD_OBJ_18].CDL_DATETIME_00001 >= @StartDateIndex AND [TBL_GPROD_OBJ_18].CDL_DATETIME_00001 < @EndMonth
                    GROUP BY [TBL_GPROD_OBJ_18].CDL_DATETIME_00001  
                ) PLAN_PRODUCAO ON ([@tblPeriod].PeriodIndex = PLAN_PRODUCAO.PeriodIndex)
                
                -- Recuperação Acumulado
                LEFT JOIN (SELECT PeriodIndex
                            , TeorAlimentacaoCobreRealAcumulado 
                            , TeorAlimentacaoOuroRealAcumulado  
                            , TeorConcentradoCobreRealAcumulado 
                            , TeorConcentradoOuroRealAcumulado 
                            , TeorRejeitoCobreRealAcumulado 
                            , TeorRejeitoOuroRealAcumulado 
                            , 100.0*((TeorAlimentacaoCobreRealAcumulado - TeorRejeitoCobreRealAcumulado) / NULLIF((TeorConcentradoCobreRealAcumulado - TeorRejeitoCobreRealAcumulado), 0.0)) * (TeorConcentradoCobreRealAcumulado / NULLIF(TeorAlimentacaoCobreRealAcumulado, 0.0)) AS RecuperacaoCobreRealAcumulado 
                            , 100.0*((TeorAlimentacaoOuroRealAcumulado - TeorRejeitoOuroRealAcumulado) / NULLIF((TeorConcentradoOuroRealAcumulado - TeorRejeitoOuroRealAcumulado), 0.0)) * (TeorConcentradoOuroRealAcumulado / NULLIF(TeorAlimentacaoOuroRealAcumulado, 0.0)) AS RecuperacaoOuroRealAcumulado 
                            
                            , TeorAlimentacaoCobreOrcadoAcumulado 
                            , TeorAlimentacaoOuroOrcadoAcumulado  
                            , TeorConcentradoCobreOrcadoAcumulado 
                            , TeorConcentradoOuroOrcadoAcumulado 
                            , TeorRejeitoCobreOrcadoAcumulado 
                            , TeorRejeitoOuroOrcadoAcumulado 
                            , 100.0*((TeorAlimentacaoCobreOrcadoAcumulado - TeorRejeitoCobreOrcadoAcumulado) / NULLIF((TeorConcentradoCobreOrcadoAcumulado - TeorRejeitoCobreOrcadoAcumulado), 0.0)) * (TeorConcentradoCobreOrcadoAcumulado / NULLIF(TeorAlimentacaoCobreOrcadoAcumulado, 0.0)) AS RecuperacaoCobreOrcadoAcumulado 
                            , 100.0*((TeorAlimentacaoOuroOrcadoAcumulado - TeorRejeitoOuroOrcadoAcumulado) / NULLIF((TeorConcentradoOuroOrcadoAcumulado - TeorRejeitoOuroOrcadoAcumulado), 0.0)) * (TeorConcentradoOuroOrcadoAcumulado / NULLIF(TeorAlimentacaoOuroOrcadoAcumulado, 0.0)) AS RecuperacaoOuroOrcadoAcumulado 
                            
                            , TeorAlimentacaoCobreProjecao 
                            , TeorAlimentacaoOuroProjecao 
                            , TeorConcentradoCobreProjecao 
                            , TeorConcentradoOuroProjecao 
                            , TeorRejeitoCobreProjecao 
                            , TeorRejeitoOuroProjecao 
                            , 100.0*((TeorAlimentacaoCobreProjecao - TeorRejeitoCobreProjecao) / NULLIF((TeorConcentradoCobreProjecao - TeorRejeitoCobreProjecao), 0.0)) * (TeorConcentradoCobreProjecao / NULLIF(TeorAlimentacaoCobreProjecao, 0.0)) AS RecuperacaoCobreProjecao 
                            , 100.0*((TeorAlimentacaoOuroProjecao - TeorRejeitoOuroProjecao) / NULLIF((TeorConcentradoOuroProjecao - TeorRejeitoOuroProjecao), 0.0)) * (TeorConcentradoOuroProjecao / NULLIF(TeorAlimentacaoOuroProjecao, 0.0)) AS RecuperacaoOuroProjecao 
                            FROM (SELECT PLAN_PLANTA.PeriodIndex
                            --, SUM(ISNULL(AlimentacaoPlantaReal, 0.0)) AS AlimentacaoPlantaReal
                            , SUM(ISNULL(TeorAlimentacaoCobreReal, 0.0) * ISNULL(AlimentacaoPlantaReal, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorAlimentacaoCobreReal, 0.0) > 0.0 THEN ISNULL(AlimentacaoPlantaReal, 0.0) ELSE 0.0 END), 0.0) AS TeorAlimentacaoCobreRealAcumulado 
                            , SUM(ISNULL(TeorAlimentacaoOuroReal, 0.0) * ISNULL(AlimentacaoPlantaReal, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorAlimentacaoOuroReal, 0.0) > 0.0 THEN ISNULL(AlimentacaoPlantaReal, 0.0) ELSE 0.0 END), 0.0) AS TeorAlimentacaoOuroRealAcumulado  
                            --, SUM(ISNULL(TeorConcentradoCobreReal, 0.0) * ISNULL(ConcentradoReal, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorConcentradoCobreReal, 0.0) > 0.0 THEN ISNULL(ConcentradoReal, 0.0) ELSE 0.0 END), 0.0) AS TeorConcentradoCobreRealAcumulado 
                            --, SUM(ISNULL(TeorConcentradoOuroReal, 0.0) * ISNULL(ConcentradoReal, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorConcentradoOuroReal, 0.0) > 0.0 THEN ISNULL(ConcentradoReal, 0.0) ELSE 0.0 END), 0.0) AS TeorConcentradoOuroRealAcumulado 
                            , SUM(ISNULL(TeorConcentradoCobreReal, 0.0) * ISNULL(AlimentacaoPlantaReal, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorConcentradoCobreReal, 0.0) > 0.0 THEN ISNULL(AlimentacaoPlantaReal, 0.0) ELSE 0.0 END), 0.0) AS TeorConcentradoCobreRealAcumulado 
                            , SUM(ISNULL(TeorConcentradoOuroReal, 0.0) * ISNULL(AlimentacaoPlantaReal, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorConcentradoOuroReal, 0.0) > 0.0 THEN ISNULL(AlimentacaoPlantaReal, 0.0) ELSE 0.0 END), 0.0) AS TeorConcentradoOuroRealAcumulado 
                            , SUM(ISNULL(TeorRejeitoCobreReal, 0.0) * ISNULL(AlimentacaoPlantaReal, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorRejeitoCobreReal, 0.0) > 0.0 THEN ISNULL(AlimentacaoPlantaReal, 0.0) ELSE 0.0 END), 0.0) AS TeorRejeitoCobreRealAcumulado 
                            , SUM(ISNULL(TeorRejeitoOuroReal, 0.0) * ISNULL(AlimentacaoPlantaReal, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorRejeitoOuroReal, 0.0) > 0.0 THEN ISNULL(AlimentacaoPlantaReal, 0.0) ELSE 0.0 END), 0.0) AS TeorRejeitoOuroRealAcumulado 
                            
                            , SUM(ISNULL(TeorAlimentacaoCobreOrcado, 0.0) * ISNULL(AlimentacaoPlantaOrcado, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorAlimentacaoCobreOrcado, 0.0) > 0.0 THEN ISNULL(AlimentacaoPlantaOrcado, 0.0) ELSE 0.0 END), 0.0) AS TeorAlimentacaoCobreOrcadoAcumulado 
                            , SUM(ISNULL(TeorAlimentacaoOuroOrcado, 0.0) * ISNULL(AlimentacaoPlantaOrcado, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorAlimentacaoOuroOrcado, 0.0) > 0.0 THEN ISNULL(AlimentacaoPlantaOrcado, 0.0) ELSE 0.0 END), 0.0) AS TeorAlimentacaoOuroOrcadoAcumulado  
                            --, SUM(ISNULL(TeorConcentradoCobreOrcado, 0.0) * ISNULL(ConcentradoOrcado, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorConcentradoCobreOrcado, 0.0) > 0.0 THEN ISNULL(ConcentradoOrcado, 0.0) ELSE 0.0 END), 0.0) AS TeorConcentradoCobreOrcadoAcumulado 
                            --, SUM(ISNULL(TeorConcentradoOuroOrcado, 0.0) * ISNULL(ConcentradoOrcado, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorConcentradoOuroOrcado, 0.0) > 0.0 THEN ISNULL(ConcentradoOrcado, 0.0) ELSE 0.0 END), 0.0) AS TeorConcentradoOuroOrcadoAcumulado 
                            , SUM(ISNULL(TeorConcentradoCobreOrcado, 0.0) * ISNULL(AlimentacaoPlantaOrcado, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorConcentradoCobreOrcado, 0.0) > 0.0 THEN ISNULL(AlimentacaoPlantaOrcado, 0.0) ELSE 0.0 END), 0.0) AS TeorConcentradoCobreOrcadoAcumulado 
                            , SUM(ISNULL(TeorConcentradoOuroOrcado, 0.0) * ISNULL(AlimentacaoPlantaOrcado, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorConcentradoOuroOrcado, 0.0) > 0.0 THEN ISNULL(AlimentacaoPlantaOrcado, 0.0) ELSE 0.0 END), 0.0) AS TeorConcentradoOuroOrcadoAcumulado 
                            , SUM(ISNULL(TeorRejeitoCobreOrcado, 0.0) * ISNULL(AlimentacaoPlantaOrcado, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorRejeitoCobreOrcado, 0.0) > 0.0 THEN ISNULL(AlimentacaoPlantaOrcado, 0.0) ELSE 0.0 END), 0.0) AS TeorRejeitoCobreOrcadoAcumulado 
                            , SUM(ISNULL(TeorRejeitoOuroOrcado, 0.0) * ISNULL(AlimentacaoPlantaOrcado, 0.0)) / NULLIF(SUM(CASE WHEN ISNULL(TeorRejeitoOuroOrcado, 0.0) > 0.0 THEN ISNULL(AlimentacaoPlantaOrcado, 0.0) ELSE 0.0 END), 0.0) AS TeorRejeitoOuroOrcadoAcumulado 
                            
                            , SUM(CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(TeorAlimentacaoCobreReal, 0.0) * ISNULL(AlimentacaoPlantaReal, 0.0) ELSE ISNULL(TeorAlimentacaoCobreCurtissimoPrazo, 0.0) * ISNULL(AlimentacaoPlantaCurtissimoPrazo, 0.0) END) / NULLIF(SUM(CASE WHEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(TeorAlimentacaoCobreReal, 0.0) ELSE ISNULL(TeorAlimentacaoCobreCurtissimoPrazo, 0.0) END > 0.0 THEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(AlimentacaoPlantaReal, 0.0) ELSE ISNULL(AlimentacaoPlantaCurtissimoPrazo, 0.0) END ELSE 0.0 END), 0.0) AS TeorAlimentacaoCobreProjecao 
                            , SUM(CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(TeorAlimentacaoOuroReal, 0.0) * ISNULL(AlimentacaoPlantaReal, 0.0) ELSE ISNULL(TeorAlimentacaoOuroCurtissimoPrazo, 0.0) * ISNULL(AlimentacaoPlantaCurtissimoPrazo, 0.0) END) / NULLIF(SUM(CASE WHEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(TeorAlimentacaoOuroReal, 0.0) ELSE ISNULL(TeorAlimentacaoOuroCurtissimoPrazo, 0.0) END > 0.0 THEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(AlimentacaoPlantaReal, 0.0) ELSE ISNULL(AlimentacaoPlantaCurtissimoPrazo, 0.0) END ELSE 0.0 END), 0.0) AS TeorAlimentacaoOuroProjecao 
                            --, SUM(CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(TeorConcentradoCobreReal, 0.0) * ISNULL(ConcentradoReal, 0.0) ELSE ISNULL(TeorConcentradoCobreCurtissimoPrazo, 0.0) * ISNULL(ConcentradoCurtissimoPrazo, 0.0) END) / NULLIF(SUM(CASE WHEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(TeorConcentradoCobreReal, 0.0) ELSE ISNULL(TeorConcentradoCobreCurtissimoPrazo, 0.0) END > 0.0 THEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(ConcentradoReal, 0.0) ELSE ISNULL(ConcentradoCurtissimoPrazo, 0.0) END ELSE 0.0 END), 0.0) AS TeorConcentradoCobreProjecao 
                            --, SUM(CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(TeorConcentradoOuroReal, 0.0) * ISNULL(ConcentradoReal, 0.0) ELSE ISNULL(TeorConcentradoOuroCurtissimoPrazo, 0.0) * ISNULL(ConcentradoCurtissimoPrazo, 0.0) END) / NULLIF(SUM(CASE WHEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(TeorConcentradoOuroReal, 0.0) ELSE ISNULL(TeorConcentradoOuroCurtissimoPrazo, 0.0) END > 0.0 THEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(ConcentradoReal, 0.0) ELSE ISNULL(ConcentradoCurtissimoPrazo, 0.0) END ELSE 0.0 END), 0.0) AS TeorConcentradoOuroProjecao 
                            , SUM(CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(TeorConcentradoCobreReal, 0.0) * ISNULL(AlimentacaoPlantaReal, 0.0) ELSE ISNULL(TeorConcentradoCobreCurtissimoPrazo, 0.0) * ISNULL(ConcentradoCurtissimoPrazo, 0.0) END) / NULLIF(SUM(CASE WHEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(AlimentacaoPlantaReal, 0.0) ELSE ISNULL(TeorConcentradoCobreCurtissimoPrazo, 0.0) END > 0.0 THEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(AlimentacaoPlantaReal, 0.0) ELSE ISNULL(ConcentradoCurtissimoPrazo, 0.0) END ELSE 0.0 END), 0.0) AS TeorConcentradoCobreProjecao 
                            , SUM(CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(TeorConcentradoOuroReal, 0.0) * ISNULL(AlimentacaoPlantaReal, 0.0) ELSE ISNULL(TeorConcentradoOuroCurtissimoPrazo, 0.0) * ISNULL(ConcentradoCurtissimoPrazo, 0.0) END) / NULLIF(SUM(CASE WHEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(AlimentacaoPlantaReal, 0.0) ELSE ISNULL(TeorConcentradoOuroCurtissimoPrazo, 0.0) END > 0.0 THEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(AlimentacaoPlantaReal, 0.0) ELSE ISNULL(ConcentradoCurtissimoPrazo, 0.0) END ELSE 0.0 END), 0.0) AS TeorConcentradoOuroProjecao 
                            , SUM(CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(TeorRejeitoCobreReal, 0.0) * ISNULL(AlimentacaoPlantaReal, 0.0) ELSE ISNULL(TeorRejeitoCobreCurtissimoPrazo, 0.0) * ISNULL(AlimentacaoPlantaCurtissimoPrazo, 0.0) END) / NULLIF(SUM(CASE WHEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(TeorRejeitoCobreReal, 0.0) ELSE ISNULL(TeorRejeitoCobreCurtissimoPrazo, 0.0) END > 0.0 THEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(AlimentacaoPlantaReal, 0.0) ELSE ISNULL(AlimentacaoPlantaCurtissimoPrazo, 0.0) END ELSE 0.0 END), 0.0) AS TeorRejeitoCobreProjecao 
                            , SUM(CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(TeorRejeitoOuroReal, 0.0) * ISNULL(AlimentacaoPlantaReal, 0.0) ELSE ISNULL(TeorRejeitoOuroCurtissimoPrazo, 0.0) * ISNULL(AlimentacaoPlantaCurtissimoPrazo, 0.0) END) / NULLIF(SUM(CASE WHEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(TeorRejeitoOuroReal, 0.0) ELSE ISNULL(TeorRejeitoOuroCurtissimoPrazo, 0.0) END > 0.0 THEN CASE WHEN PLAN_PLANTA.PeriodIndex < @EndDateIndex THEN ISNULL(AlimentacaoPlantaReal, 0.0) ELSE ISNULL(AlimentacaoPlantaCurtissimoPrazo, 0.0) END ELSE 0.0 END), 0.0) AS TeorRejeitoOuroProjecao 
                    
                    FROM
                    (SELECT [@tblPeriod].PeriodIndex
                        , SUM([@tblTeores].MoagemToneladasSecas) AS AlimentacaoPlantaReal
                        , SUM([@tblTeores].Concentrado) AS ConcentradoReal
                        , SUM(ISNULL([@tblTeores].P80Flotacao, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].P80Flotacao, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS P80FlotacaoReal 
                        , SUM(ISNULL([@tblTeores].TeorAlimentacaoCobre, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorAlimentacaoCobre, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS TeorAlimentacaoCobreReal 
                        , SUM(ISNULL([@tblTeores].TeorAlimentacaoOuro, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorAlimentacaoOuro, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS TeorAlimentacaoOuroReal 
                        , SUM(ISNULL([@tblTeores].TeorAlimentacaoEnxofre, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorAlimentacaoEnxofre, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS TeorAlimentacaoEnxofreReal 
                        --, SUM(ISNULL([@tblTeores].TeorCFColunaCobre, 0.0) * [@tblTeores].Concentrado) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorCFColunaCobre, 0.0) > 0.0 THEN [@tblTeores].Concentrado ELSE 0.0 END), 0.0) AS TeorConcentradoCobreReal 
                        --, SUM(ISNULL([@tblTeores].TeorCFColunaOuro, 0.0) * [@tblTeores].Concentrado) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorCFColunaOuro, 0.0) > 0.0 THEN [@tblTeores].Concentrado ELSE 0.0 END), 0.0) AS TeorConcentradoOuroReal 
                        , SUM(ISNULL([@tblTeores].TeorCFColunaCobre, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorCFColunaCobre, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS TeorConcentradoCobreReal 
                        , SUM(ISNULL([@tblTeores].TeorCFColunaOuro, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorCFColunaOuro, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS TeorConcentradoOuroReal 
                        , SUM(ISNULL([@tblTeores].TeorRejeitoCobre, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorRejeitoCobre, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS TeorRejeitoCobreReal 
                        , SUM(ISNULL([@tblTeores].TeorRejeitoOuro, 0.0) * [@tblTeores].MoagemToneladasSecas) / NULLIF(SUM(CASE WHEN ISNULL([@tblTeores].TeorRejeitoOuro, 0.0) > 0.0 THEN [@tblTeores].MoagemToneladasSecas ELSE 0.0 END), 0.0) AS TeorRejeitoOuroReal 
                    FROM @tblPeriod
                    INNER JOIN @tblTeores ON ([@tblTeores].PeriodIndex >= [@tblPeriod].StartPeriod AND [@tblTeores].PeriodIndex < [@tblPeriod].EndPeriod)
                    GROUP BY  [@tblPeriod].PeriodIndex) TEOR_ACUMULADO
                    FULL OUTER JOIN 
                    (SELECT [TBL_GPROD_OBJ_15].CDL_DATETIME_00001 AS PeriodIndex
                        , SUM(CASE WHEN CDL_NUMBER_00006 = @planType THEN ISNULL([CDL_NUMBER_00009], 0.0) ELSE 0.0 END) AS AlimentacaoPlantaOrcado
                        , SUM(CASE WHEN CDL_NUMBER_00006 = 4 THEN ISNULL([CDL_NUMBER_00009], 0.0) ELSE 0.0 END) AS AlimentacaoPlantaCurtissimoPrazo
                    FROM [dbo].[TBL_GPROD_OBJ_15]
                    WHERE [TBL_GPROD_OBJ_15].[CDL_STR50_00003] = 'Planejamento - Moagem' AND [TBL_GPROD_OBJ_15].CDL_NUMBER_00001 = 1 AND [TBL_GPROD_OBJ_15].CDL_NUMBER_00005 = 4 AND [TBL_GPROD_OBJ_15].CDL_DATETIME_00001 >= @StartDateIndex AND [TBL_GPROD_OBJ_15].CDL_DATETIME_00001 < @EndMonth
                    GROUP BY [TBL_GPROD_OBJ_15].CDL_DATETIME_00001
                    ) PLAN_PLANTA ON (TEOR_ACUMULADO.PeriodIndex = PLAN_PLANTA.PeriodIndex)
                
                    FULL OUTER JOIN 
                    (SELECT PeriodIndex
                            ,ConcentradoOrcado
                            ,TeorAlimentacaoCobreOrcado
                            ,TeorAlimentacaoOuroOrcado
                            ,TeorConcentradoCobreOrcado
                            ,TeorConcentradoOuroOrcado
                            --,RecuperacaoCobreOrcado
                            --,RecuperacaoOuroOrcado
                            ,ISNULL(100.0 * (TeorAlimentacaoCobreOrcado / 100.0) * (TeorConcentradoCobreOrcado / 100.0) * ((RecuperacaoCobreOrcado / 100.0) - 1.0) / NULLIF(((RecuperacaoCobreOrcado / 100.0) * (TeorAlimentacaoCobreOrcado / 100.0) - (TeorConcentradoCobreOrcado / 100.0)), 0.0), 0.0) AS TeorRejeitoCobreOrcado
                            ,ISNULL((TeorAlimentacaoOuroOrcado) * (TeorConcentradoOuroOrcado) * ((RecuperacaoOuroOrcado / 100.0) - 1.0) / NULLIF(((RecuperacaoOuroOrcado / 100.0) * (TeorAlimentacaoOuroOrcado) - (TeorConcentradoOuroOrcado)), 0.0), 0.0) AS TeorRejeitoOuroOrcado
                        
                            ,ConcentradoCurtissimoPrazo
                            ,TeorAlimentacaoCobreCurtissimoPrazo
                            ,TeorAlimentacaoOuroCurtissimoPrazo
                            ,TeorConcentradoCobreCurtissimoPrazo
                            ,TeorConcentradoOuroCurtissimoPrazo
                            --,RecuperacaoCobreCurtissimoPrazo
                            --,RecuperacaoOuroCurtissimoPrazo
                            ,ISNULL(100.0 * (TeorAlimentacaoCobreCurtissimoPrazo / 100.0) * (TeorConcentradoCobreCurtissimoPrazo / 100.0) * ((RecuperacaoCobreCurtissimoPrazo / 100.0) - 1.0) / NULLIF(((RecuperacaoCobreCurtissimoPrazo / 100.0) * (TeorAlimentacaoCobreCurtissimoPrazo / 100.0) - (TeorConcentradoCobreCurtissimoPrazo / 100.0)), 0.0), 0.0) AS TeorRejeitoCobreCurtissimoPrazo
                            ,ISNULL((TeorAlimentacaoOuroCurtissimoPrazo) * (TeorConcentradoOuroCurtissimoPrazo) * ((RecuperacaoOuroCurtissimoPrazo / 100.0) - 1.0) / NULLIF(((RecuperacaoOuroCurtissimoPrazo / 100.0) * (TeorAlimentacaoOuroCurtissimoPrazo) - (TeorConcentradoOuroCurtissimoPrazo)), 0.0), 0.0) AS TeorRejeitoOuroCurtissimoPrazo
                    FROM 
                    (SELECT CDL_DATETIME_00001 AS PeriodIndex
                        , SUM(CASE WHEN CDL_NUMBER_00006 = @planType THEN ISNULL([CDL_NUMBER_00015], 0.0) ELSE 0.0 END) AS ConcentradoOrcado
                        , AVG(CASE WHEN CDL_NUMBER_00006 = @planType THEN ([CDL_NUMBER_00007]) ELSE NULL END) AS TeorAlimentacaoCobreOrcado
                        , AVG(CASE WHEN CDL_NUMBER_00006 = @planType THEN ([CDL_NUMBER_00008]) ELSE NULL END) AS TeorAlimentacaoOuroOrcado
                        , AVG(CASE WHEN CDL_NUMBER_00006 = @planType THEN ([CDL_NUMBER_00013]) ELSE NULL END) AS TeorConcentradoCobreOrcado
                        , AVG(CASE WHEN CDL_NUMBER_00006 = @planType THEN ([CDL_NUMBER_00014]) ELSE NULL END) AS TeorConcentradoOuroOrcado
                        , AVG(CASE WHEN CDL_NUMBER_00006 = @planType THEN ([CDL_NUMBER_00011]) ELSE NULL END) AS RecuperacaoCobreOrcado
                        , AVG(CASE WHEN CDL_NUMBER_00006 = @planType THEN ([CDL_NUMBER_00012]) ELSE NULL END) AS RecuperacaoOuroOrcado
                        
                        , SUM(CASE WHEN CDL_NUMBER_00006 = 4 THEN ISNULL([CDL_NUMBER_00015], 0.0) ELSE 0.0 END) AS ConcentradoCurtissimoPrazo
                        , AVG(CASE WHEN CDL_NUMBER_00006 = 4 THEN ([CDL_NUMBER_00007]) ELSE NULL END) AS TeorAlimentacaoCobreCurtissimoPrazo
                        , AVG(CASE WHEN CDL_NUMBER_00006 = 4 THEN ([CDL_NUMBER_00008]) ELSE NULL END) AS TeorAlimentacaoOuroCurtissimoPrazo
                        , AVG(CASE WHEN CDL_NUMBER_00006 = 4 THEN ([CDL_NUMBER_00013]) ELSE NULL END) AS TeorConcentradoCobreCurtissimoPrazo
                        , AVG(CASE WHEN CDL_NUMBER_00006 = 4 THEN ([CDL_NUMBER_00014]) ELSE NULL END) AS TeorConcentradoOuroCurtissimoPrazo
                        , AVG(CASE WHEN CDL_NUMBER_00006 = 4 THEN ([CDL_NUMBER_00011]) ELSE NULL END) AS RecuperacaoCobreCurtissimoPrazo
                        , AVG(CASE WHEN CDL_NUMBER_00006 = 4 THEN ([CDL_NUMBER_00012]) ELSE NULL END) AS RecuperacaoOuroCurtissimoPrazo
                        FROM [dbo].[TBL_GPROD_OBJ_18]  
                    WHERE [TBL_GPROD_OBJ_18].CDL_NUMBER_00001 = 1 AND [TBL_GPROD_OBJ_18].CDL_NUMBER_00005 = 4 AND [TBL_GPROD_OBJ_18].CDL_DATETIME_00001 >= @StartDateIndex AND [TBL_GPROD_OBJ_18].CDL_DATETIME_00001 < @EndMonth
                    GROUP BY [TBL_GPROD_OBJ_18].CDL_DATETIME_00001 ) AUX ) TEOR_PLAN_ACUMUL ON (TEOR_ACUMULADO.PeriodIndex = TEOR_PLAN_ACUMUL.PeriodIndex) 
                    GROUP BY PLAN_PLANTA.PeriodIndex
                ) AUX ) REC_ACUMULADO ON ([@tblPeriod].PeriodIndex = REC_ACUMULADO.PeriodIndex)
                    
                    
                    
        ORDER BY [@tblPeriod].PeriodIndex
        
        
        

        
    SET NOCOUNT OFF;
    END




   
